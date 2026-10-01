#!/usr/bin/env python3
"""Action HW checks — run on the DUT under live TRex traffic.

One tool that verifies each rule *action* behaves at line rate under a matching
flood (the fixed-flood-31 profile: UDP dport 8000-8255).  Subcommands:

  dscp       — DSCP-mark fires and marked packets PASS, not drop (dropped ~0%).
  ratelimit  — per-rule/per-worker token bucket: --mode conform | exceed.
  psample    — sampled copies reach the kernel psample channel, 0 send failures.

The dscp/ratelimit gates read the plugin's own conform/exceed/drop counters
(deterministic, not egress Mpps); psample reads the copies back with the shipped
consumer (test/psample_reader.py).  All require UDP dport 8000-8255 traffic
(e.g. fixed-flood-31) to be flowing.

Exit codes: 0 pass · 1 assertion failed · 2 setup error (no traffic / no PAPI /
no psample module).

Usage:
  docker exec <dut-container> python3 /src/labs/hw/dut/action_check.py \\
      dscp       [--warm 4 --sample 6 --max-drop-pct 1]
      ratelimit  --mode conform|exceed [--warm 4 --sample 6 --min-pct 99]
      psample    [--ratio 1048576 --group 7 --warm 3 --window 6]
"""
import argparse
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench

CLI_SOCKET = "/run/vpp/cli.sock"

DSCP_MARK_VALUE = 46
CIR_CONFORM_BPS = 90_000_000_000
CIR_EXCEED_BPS = 5_000_000
BURST_BYTES = 65535

def _fmt_rate(bps):
    return f"{bps / 1e9:g} Gbps" if bps >= 1_000_000_000 else f"{bps / 1e6:g} Mbps"

def check_dscp(args):
    action = {"type": bench.ACTION_DSCP_MARK, "dscp_value": DSCP_MARK_VALUE,
              "rate_bps": 0, "burst_bytes": 0}
    vpp = bench.connect()
    try:
        bench.clear_rules(vpp)
        entries = bench._port_hot_entries(5, action=action)
        bench._load_rules(vpp, entries,
                          f"DSCP-mark rules (mark {DSCP_MARK_VALUE})")
        time.sleep(args.warm)
        vpp.api.fastacl_counters_clear()
        time.sleep(args.sample)

        matched, _conform, _exceed = bench.rule_action_stats(vpp)
        c = vpp.api.fastacl_counters_get()
        processed = int(c.total_processed)
        dropped = int(c.total_dropped)
        if matched == 0:
            print("FAIL: no packets hit the DSCP-mark rules — is UDP dport "
                  "8000-8255 traffic (e.g. fixed-flood-31) flowing?",
                  file=sys.stderr)
            return 2

        drop_pct = 100.0 * dropped / processed if processed else 0.0
        ok = drop_pct <= args.max_drop_pct
        print(f"dscp-mark: matched={matched:,}  processed={processed:,}  "
              f"dropped={dropped:,} ({drop_pct:.3f}%)  "
              f"dut={c.total_pps / 1e6:.1f} Mpps  "
              f"(need dropped <= {args.max_drop_pct:.0f}%)  "
              f"{'PASS' if ok else 'FAIL'}")
        if not ok:
            print("FAIL: DSCP-mark packets were dropped — mark must pass "
                  "(rewrite ToS + continue), not drop.", file=sys.stderr)
        return 0 if ok else 1
    finally:
        vpp.disconnect()

def check_ratelimit(args):
    cir = CIR_CONFORM_BPS if args.mode == "conform" else CIR_EXCEED_BPS
    action = {"type": bench.ACTION_RATE_LIMIT, "dscp_value": 0,
              "rate_bps": cir, "burst_bytes": BURST_BYTES}
    vpp = bench.connect()
    try:
        bench.clear_rules(vpp)
        entries = bench._port_hot_entries(5, action=action)
        bench._load_rules(vpp, entries,
                          f"rate-limit {args.mode} rules ({_fmt_rate(cir)})")
        time.sleep(args.warm)
        vpp.api.fastacl_counters_clear()
        time.sleep(args.sample)

        pkts, conform, exceed = bench.rule_action_stats(vpp)
        if pkts == 0:
            print("FAIL: no packets hit the rate-limit rules — is UDP dport "
                  "8000-8255 traffic (e.g. fixed-flood-31) flowing?",
                  file=sys.stderr)
            return 2

        conform_pct = 100.0 * conform / pkts
        exceed_pct = 100.0 * exceed / pkts
        got = conform_pct if args.mode == "conform" else exceed_pct
        ok = got >= args.min_pct
        print(f"rate-limit {args.mode}: matched={pkts:,}  "
              f"conform={conform_pct:.2f}%  exceed={exceed_pct:.2f}%  "
              f"(need {args.mode} >= {args.min_pct:.0f}%)  "
              f"{'PASS' if ok else 'FAIL'}")
        return 0 if ok else 1
    finally:
        vpp.disconnect()

_vppctl = bench.vppctl

def _sampling_stats_for_group(group):
    """Sum the sampled and send-failed columns of `show fastacl sampling`.

    Columns are rule, rate, group, sampled, send-failed.
    """
    sampled = failed = 0
    seen = False
    for line in _vppctl("show fastacl sampling").splitlines():
        parts = line.split()
        if len(parts) == 5 and parts[2] == str(group) and parts[1].startswith("1:"):
            seen = True
            sampled += int(parts[3])
            failed += int(parts[4])
    return sampled, failed, seen

def _matched_packets():
    """Packets the sampling rule has dropped so far.

    The check installs exactly one rule and it is action drop, so the aggregate
    dropped counter is that rule's matched count.  Read as a delta by callers.
    """
    vpp = bench.connect()
    try:
        return int(vpp.api.fastacl_counters_get().total_dropped)
    except Exception:
        return 0
    finally:
        try:
            vpp.disconnect()
        except Exception:
            pass

def check_psample(args):
    sys.path.insert(0, "/src/labs/hw/dut")
    from psample_reader import PsampleReader, resolve

    try:
        subprocess.run(["modprobe", "psample"], capture_output=True)
    except FileNotFoundError:
        pass
    fam, grp = resolve()
    if not fam or not grp:
        print("SKIP: psample kernel module not available on the DUT",
              file=sys.stderr)
        return 2

    out = _vppctl("fastacl psample enable")
    if "not found" in out or "failed" in out:
        print(f"FAIL(setup): fastacl psample enable: {out.strip()!r}",
              file=sys.stderr)
        return 2

    _vppctl("fastacl rule del all")
    out = _vppctl(
        f"fastacl rule add order 100 proto 17 dst-port 8000-8255 "
        f"action drop sample {args.ratio} group {args.group}"
    )
    if "rule index" not in out:
        print(f"FAIL(setup): rule add: {out.strip()!r}", file=sys.stderr)
        return 2

    try:
        time.sleep(args.warm)
        reader = PsampleReader()
    except RuntimeError as e:
        print(f"FAIL(setup): {e}", file=sys.stderr)
        return 2

    # Both counters have to be deltas over exactly the collection window.  The
    # plugin keeps sampling through the warm-up and after the reader closes, so
    # comparing its cumulative total against a shorter capture reports loss
    # that is purely the difference in observation period.
    taken0, failed0, seen_rule = _sampling_stats_for_group(args.group)
    matched0 = _matched_packets()
    try:
        samples = reader.collect(timeout=args.window)
    finally:
        reader.close()
    taken1, failed1, seen_after = _sampling_stats_for_group(args.group)
    matched1 = _matched_packets()

    sampled = taken1 - taken0
    failed = failed1 - failed0
    matched = matched1 - matched0
    seen_rule = seen_rule or seen_after
    _vppctl("fastacl psample disable")
    _vppctl("fastacl rule del all")

    if not seen_rule:
        print("FAIL(setup): sample rule not present in 'show fastacl sampling'",
              file=sys.stderr)
        return 2
    if not samples:
        print("FAIL(setup): no samples arrived — is UDP dport 8000-8255 "
              "(e.g. fixed-flood-31) flowing?", file=sys.stderr)
        return 2

    s = samples[0]
    rate_ok = s.get("rate") == args.ratio
    group_ok = s.get("group") == args.group
    meta_ok = s.get("origsize", 0) > 0 and s.get("bytes", 0) > 0

    # What the configured ratio should have produced, and how much of it
    # actually reached a collector.  send-failed only counts sends the plugin
    # itself refused; a sample lost in the kernel channel or never taken shows
    # up here and nowhere else, which is the failure an operator would see as
    # under-reported attack volume.
    expected = matched // args.ratio if matched else 0
    took_pct = 100.0 * sampled / expected if expected else 0.0
    got_pct = 100.0 * len(samples) / sampled if sampled else 0.0

    take_ok = expected == 0 or abs(took_pct - 100.0) <= args.max_take_skew_pct
    deliver_ok = sampled == 0 or got_pct >= args.min_delivered_pct
    ok = (rate_ok and group_ok and meta_ok and failed == 0
          and take_ok and deliver_ok)

    print(f"psample: matched={matched:,}  expected={expected:,}  "
          f"taken={sampled:,} ({took_pct:.1f}%)  "
          f"delivered={len(samples):,} ({got_pct:.1f}% of taken)  "
          f"send-failed={failed}  rate=1:{s.get('rate')}  "
          f"group={s.get('group')}  payload={s.get('bytes')}B  "
          f"{'PASS' if ok else 'FAIL'}")
    if not ok:
        if not rate_ok or not group_ok:
            print("FAIL: sample metadata mismatch", file=sys.stderr)
        if failed:
            print(f"FAIL: {failed} sends failed — sampled stream is not "
                  "complete", file=sys.stderr)
        if not take_ok:
            print(f"FAIL: plugin took {took_pct:.1f}% of the samples the "
                  f"1:{args.ratio} ratio calls for (tolerance "
                  f"{args.max_take_skew_pct:.0f}%)", file=sys.stderr)
        if not deliver_ok:
            print(f"FAIL: only {got_pct:.1f}% of taken samples reached the "
                  f"collector (need >= {args.min_delivered_pct:.0f}%) — "
                  f"{sampled - len(samples):,} lost with send-failed=0, so "
                  f"they went missing below the plugin", file=sys.stderr)
    return 0 if ok else 1

def main():
    ap = argparse.ArgumentParser(description="FastACL per-action HW checks")
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("dscp", help="DSCP-mark fires and passes")
    d.add_argument("--warm", type=float, default=4.0)
    d.add_argument("--sample", type=float, default=6.0)
    d.add_argument("--max-drop-pct", type=float, default=1.0,
                   help="max %% of processed packets allowed to drop (~0)")
    d.set_defaults(fn=check_dscp)

    r = sub.add_parser("ratelimit", help="token-bucket conform/exceed")
    r.add_argument("--mode", required=True, choices=["conform", "exceed"])
    r.add_argument("--warm", type=float, default=4.0)
    r.add_argument("--sample", type=float, default=6.0)
    r.add_argument("--min-pct", type=float, default=99.0,
                   help="min %% of matched packets in the expected class")
    r.set_defaults(fn=check_ratelimit)

    p = sub.add_parser("psample", help="samples reach the psample channel")
    p.add_argument("--ratio", type=int, default=1048576)
    p.add_argument("--group", type=int, default=7)
    p.add_argument("--warm", type=float, default=3.0)
    p.add_argument("--window", type=float, default=6.0)
    p.add_argument("--max-take-skew-pct", type=float, default=15.0,
                   help="how far the taken count may sit from matched/ratio")
    p.add_argument("--min-delivered-pct", type=float, default=95.0,
                   help="min %% of taken samples that must reach a collector")
    p.set_defaults(fn=check_psample)

    args = ap.parse_args()
    return args.fn(args)

if __name__ == "__main__":
    sys.exit(main())
