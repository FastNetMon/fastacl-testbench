#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Turn a bench results file (JSON lines) into report.md, results.csv and meta.json.

The report is meant to be read on its own, by someone outside the lab: it names
the rig as measured on the machines, the method, what every scenario and traffic
profile is, and every measurement with its limits and verdict.

Exits non-zero when any check failed or nothing was measured, unless --no-gate
is given, so a calibration run still publishes its report.
"""

import argparse
import csv
import datetime
import json
import os
import re
import sys

STRATEGY = "https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md"
LINE_RATE_64B_MPPS = 142.05
FORBIDDEN = re.compile(r"\.ts\.net|192\.168\.\d+\.\d+|tskey-|PRIVATE KEY")

SCENARIOS = {
    "0rules": "no rules (forwarding baseline)",
    "5rules-drop": "5 hot port-range drop rules",
    "1m-rules-drop": "983,045 rules: 983,040 cold /24 drops + 5 hot rules",
    "1m-rules-drop-ip6": "983,040 IPv6 rules: cold destination /64 drops",
    "1m-rules-drop-proto": "983,040 rules: destination /24 + protocol (folded compact key)",
    "tsweep": "rule-diversity sweep: many distinct mask shapes",
    "multivector": "rules for several attack families at once",
    "country-set-drop": "20,000 source prefixes (/10 to /24) in one named set, one drop rule",
    "country-rules-drop": "the same 20,000 source prefixes as one rule each",
    "5rules-ratelimit-conform": "5 rate-limit rules, traffic under the limit",
    "5rules-ratelimit-exceed": "5 rate-limit rules, traffic over the limit",
}

ATTACKS = {
    "udp-rand": "UDP flood, random source and ports",
    "syn-flood": "TCP SYN flood",
    "ack-flood": "TCP ACK flood",
    "icmp-flood": "ICMP echo flood",
    "frag-flood": "IP fragment flood",
    "fixed-flood-31": "31 fixed UDP flows balanced across RSS queues",
    "fwd-flood-32": "32 fixed flows that no rule matches (forwarded)",
    "tcp-flows-31": "31 fixed TCP flows",
    "cold-scan": "scan across N destination /24s: N simultaneously active flows",
    "cold-scan-scatter": "cold-scan with targets spread through the rule table",
    "cold-scan-imix": "cold-scan with IMIX frames",
    "ipv6-flood": "IPv6 UDP flood",
    "ip6-cold-scan": "IPv6 scan across N destinations",
    "reflection-mix": "amplification/reflection source-port mix",
    "multivector": "UDP + TCP + ICMP + fragments at once",
    "mix-sizes": "mixed frame sizes",
    "mix-protos": "mixed protocols",
    "mix-udptcp": "UDP and TCP mix",
    "mix-burst": "bursty traffic",
}

MIXED = {"cold-scan-imix": "IMIX 64/570/1518 B, 7:4:1", "mix-sizes": "mixed sizes",
         "reflection-mix": "mixed sizes"}

TRIALS = {
    "oneport": "5 s warm-up, 10 s sample",
    "flows": "20 s warm-up, 30 s sample",
    "survey": "10 s warm-up, 15 s sample",
    "ceiling": "5 s warm-up, 15 s sample per row",
    "dpu": "4 s warm-up, 15 s sample",
}

SECTIONS = [
    ("load", "Scenario loading", [("scenario", "scenario"), ("detail", "detail"),
                                  ("verdict", "verdict")]),
    ("oneport", "One-port gates (drop and forward)", [
        ("scenario", "scenario"), ("rules", "rules"), ("attack", "traffic"), ("frame", "frame"),
        ("offered_mpps", "offered Mpps"), ("dut_mpps", "absorbed Mpps"),
        ("floor", "floor Mpps"), ("nic_lost_pct", "NIC loss %"),
        ("max_nic_lost_pct", "loss limit %"), ("cyc_pkt", "cycles/pkt"),
        ("max_cyc", "cycle limit"), ("verdict", "verdict")]),
    ("sets-tuples", "Prefix-set tuple count", [
        ("scenario", "scenario"), ("rules", "rules"), ("tuples", "tuples"),
        ("max_tuples", "limit"), ("verdict", "verdict")]),
    ("flows", "Working-set gates (simultaneously active flows)", [
        ("scenario", "scenario"), ("rules", "rules"), ("attack", "traffic"), ("frame", "frame"),
        ("flows", "active flows"), ("offered_mpps", "offered Mpps"),
        ("dut_mpps", "absorbed Mpps"), ("floor", "floor Mpps"), ("nic_lost_pct", "NIC loss %"),
        ("max_nic_lost_pct", "loss limit %"), ("cyc_pkt", "cycles/pkt"),
        ("max_cyc", "cycle limit"), ("verdict", "verdict")]),
    ("psample", "psample sampling under load", [("attack", "traffic"),
                                                ("detail", "detail"), ("verdict", "verdict")]),
    ("ceiling", "Ceiling proof (ingress vs egress budget)", [
        ("scenario", "egress streams dropped"), ("offered_mpps", "offered Mpps"),
        ("dut_mpps", "RX Mpps"), ("tx_mpps", "TX Mpps"), ("nic_lost_pct", "NIC loss %")]),
    ("survey", "All survey measurements", [
        ("sweep", "sweep"), ("scenario", "scenario"), ("nrules", "rules loaded"), ("rules", "rules"),
        ("attack", "traffic"), ("frame", "frame"),
        ("flows", "active flows"), ("offered_mpps", "offered Mpps"),
        ("dut_mpps", "absorbed Mpps"), ("nic_lost_pct", "NIC loss %"),
        ("cyc_pkt", "cycles/pkt")]),
    ("dpu", "BlueField-3 Arm drop line rate", [
        ("scenario", "test"), ("dut_mpps", "absorbed Mpps"), ("mpps_min", "min"), ("mpps_max", "max"),
        ("trials", "trials"), ("cyc_pkt", "ticks/pkt"), ("floor", "floor Mpps"),
        ("verdict", "verdict")]),
]


def load(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def fmt(value):
    if isinstance(value, float):
        return f"{value:.0f}" if value.is_integer() else f"{value:.3g}" if value < 10 else f"{value:.1f}"
    return "" if value is None else str(value)


def enrich(row):
    row = dict(row)
    if row.get("scenario") in SCENARIOS:
        row["rules"] = SCENARIOS[row["scenario"]].split(":")[0]
    if row.get("frame") not in (None, ""):
        row["frame"] = "IMIX 7:4:1" if row["frame"] == "imix" else f"{fmt(row['frame'])} B"
    elif row.get("attack"):
        row["frame"] = MIXED.get(row["attack"], "64 B")
    return row


def rig_table(rig, meta):
    rows = [
        ("Topology", f"2-node: {meta['gen']} (TRex) cabled back to back to {meta['dut']}, no switch"),
        ("DUT CPU", f"{rig.get('dut_cpu', '?')} ({fmt(rig.get('dut_cores'))} CPUs)"),
        ("DUT NIC", f"{rig.get('dut_nic', '?')}, link {rig.get('link_speed', '?')}"),
        ("DUT kernel", rig.get("dut_kernel", "?")),
        ("DUT software", rig.get("dut_os", "")),
        ("NIC driver", rig.get("dut_driver", "")),
        ("Generator", f"{rig.get('gen_cpu', '?')} ({fmt(rig.get('gen_cores'))} CPUs), "
                      f"{rig.get('gen_nic', '?')}, TRex {fmt(rig.get('trex_version'))}"),
        ("VPP", f"{rig.get('vpp_version', '?')}, {fmt(rig.get('vpp_workers'))} worker threads"
                + (f", RX/TX ring {fmt(rig.get('rx_desc'))}/{fmt(rig.get('tx_desc'))}"
                   if rig.get("rx_desc") else "")),
        ("FastACL", f"{rig.get('plugin_version', '?')} from release {meta['release']}, "
                    f"licence {rig.get('licence', '?')} (expires {rig.get('licence_expires', '?')})"),
        ("Testbench", meta["testbench"]),
        ("Run", meta["run_url"] or "local"),
    ]
    return ["| | |", "|---|---|"] + [f"| {k} | {v} |" for k, v in rows if v]


def method(rig, benches):
    target = fmt(rig.get("target_mpps"))
    lines = [
        "## Method",
        "",
        f"- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is "
        f"{LINE_RATE_64B_MPPS} Mpps.",
        f"- 64 B traffic is offered at {target} Mpps and larger frames at 100 Gbps"
        + (f"; mixed-size traffic is offered at {fmt(rig.get('target_gbps_mixed'))} Gbps (a packet "
           f"rate is only a fixed bit rate when every frame is the same size)."
           if rig.get("target_gbps_mixed") else "."),
        "- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule "
        "or forwarded), from counter deltas over the sample window.",
        "- **NIC loss %**: packets that reached the DUT port but never reached VPP "
        "(`rx_phy - rx_good`), i.e. lost inside the adapter.",
        "- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).",
        "- A gate passes when every value is within its limit; survey and ceiling rows are recorded "
        "without a verdict.",
        "- Trials: " + "; ".join(f"{b} {TRIALS[b]}" for b in TRIALS if b in benches) + ".",
        f"- Full methodology: [test strategy]({STRATEGY}).",
        "",
    ]
    return lines


def legend(rows):
    used_s = sorted({r["scenario"] for r in rows if r.get("scenario") in SCENARIOS})
    used_a = sorted({r["attack"] for r in rows if r.get("attack") in ATTACKS})
    lines = ["## Scenarios and traffic in this run", ""]
    if used_s:
        lines += ["| scenario | rules loaded |", "|---|---|"]
        lines += [f"| `{s}` | {SCENARIOS[s]} |" for s in used_s] + [""]
    lines += ["| traffic | profile |", "|---|---|"]
    lines += [f"| `{a}` | {ATTACKS[a]} ({MIXED.get(a, '64 B')}) |" for a in used_a]
    return lines + [""]


IMIX_AVG_FRAME = (64 * 7 + 570 * 4 + 1518 * 1) / 12


def wire_gbps(mpps, frame):
    if frame == "imix":
        frame = IMIX_AVG_FRAME
    try:
        return mpps * (float(frame) + 24) * 8 / 1000
    except (TypeError, ValueError):
        return None


def target_mpps(row, rig):
    frame = row.get("frame")
    if isinstance(frame, (int, float)) and frame > 64:
        return 100e3 / ((frame + 24) * 8)
    if row.get("attack") in MIXED:
        return None
    return rig.get("target_mpps")


def limited_by(row, rig):
    offered, absorbed = row.get("offered_mpps"), row.get("dut_mpps")
    if not isinstance(offered, (int, float)) or not isinstance(absorbed, (int, float)) or not offered:
        return ""
    if absorbed < 0.99 * offered:
        return "DUT"
    target = target_mpps(row, rig)
    if target and offered < 0.97 * target:
        return "generator"
    return "offered rate"


def table(header, body):
    return (["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
            + ["| " + " | ".join(fmt(c) for c in row) + " |" for row in body] + [""])


def summary(data, rig):
    sw = lambda name: [r for r in data if r.get("bench") == "survey" and r.get("sweep") == name]
    out = []
    rules = sorted(sw("rules"), key=lambda r: r.get("nrules") or 0)
    if rules:
        out += ["### Rules (64 B, drop)", ""]
        out += table(["rules", "traffic", "offered Mpps", "absorbed Mpps", "cycles/pkt", "limited by"],
                     [[r.get("nrules"), r.get("attack"), r.get("offered_mpps"), r.get("dut_mpps"),
                       r.get("cyc_pkt"), limited_by(r, rig)] for r in rules])
    attacks = sw("attacks")
    if attacks:
        by = {}
        for r in attacks:
            by.setdefault(r.get("attack"), {})[r.get("scenario")] = r
        body = []
        for a, s in by.items():
            few, many = s.get("5rules-drop", {}), s.get("1m-rules-drop", {})
            body.append([a, few.get("offered_mpps"), few.get("dut_mpps"), few.get("cyc_pkt"),
                         limited_by(few, rig), many.get("offered_mpps"), many.get("dut_mpps"),
                         many.get("cyc_pkt"), limited_by(many, rig)])
        out += ["### Attack types (64 B unless the profile says otherwise)", ""]
        out += table(["traffic", "5 rules: offered", "absorbed Mpps", "cyc/pkt", "limited by",
                      "983K rules: offered", "absorbed Mpps", "cyc/pkt", "limited by"], body)
    flows = sw("flows")
    if flows:
        fam = {"1m-rules-drop": "IPv4", "1m-rules-drop-ip6": "IPv6"}
        by = {}
        for r in flows:
            by.setdefault(int(r.get("flows") or 0), {})[fam.get(r.get("scenario"), "?")] = r
        body = [[f, by[f].get("IPv4", {}).get("dut_mpps"), by[f].get("IPv4", {}).get("cyc_pkt"),
                 by[f].get("IPv6", {}).get("dut_mpps"), by[f].get("IPv6", {}).get("cyc_pkt"),
                 limited_by(by[f].get("IPv4", {}), rig) or limited_by(by[f].get("IPv6", {}), rig)]
                for f in sorted(by)]
        out += ["### Active flows (983K rules, 64 B, drop)", ""]
        out += table(["active flows", "IPv4 Mpps", "IPv4 cyc/pkt", "IPv6 Mpps", "IPv6 cyc/pkt",
                      "limited by"], body)
        for name in ("IPv4", "IPv6"):
            held = [f for f in sorted(by) if name in by[f]
                    and (by[f][name].get("dut_mpps") or 0) >= 0.99 * (by[f][name].get("offered_mpps") or 1e9)]
            if held:
                out.append(f"- {name}: the offered rate is held up to {held[-1]:,} active flows.")
        out.append("")
    frames = sw("frames")
    if frames:
        by = {}
        for r in frames:
            by.setdefault(str(r.get("frame")), {})[r.get("scenario")] = r
        def key(f):
            return (1, 0) if f == "imix" else (0, float(f))
        body = []
        for f in sorted(by, key=key):
            d, fw = by[f].get("5rules-drop", {}), by[f].get("0rules", {})
            label = "IMIX 7:4:1" if f == "imix" else f"{float(f):.0f} B"
            body.append([label, d.get("dut_mpps"),
                         wire_gbps(d.get("dut_mpps") or 0, f), limited_by(d, rig), fw.get("dut_mpps"),
                         wire_gbps(fw.get("dut_mpps") or 0, f), limited_by(fw, rig)])
        out += ["### Packet size (1 × 100G ingress)", ""]
        out += table(["frame", "drop Mpps", "drop Gbps (wire)", "drop limited by", "forward Mpps",
                      "forward Gbps (wire)", "forward limited by"], body)
    dpu = [r for r in data if r.get("bench") == "dpu" and r.get("frame") not in (None, "")]
    if dpu:
        def dkey(r):
            return (1, 0) if r["frame"] == "imix" else (0, float(r["frame"]))
        body = []
        for r in sorted(dpu, key=dkey):
            f, m = r["frame"], r.get("dut_mpps") or 0
            size = IMIX_AVG_FRAME if f == "imix" else float(f)
            body.append(["IMIX 7:4:1" if f == "imix" else f"{size:.0f} B", r.get("rules"), m,
                         wire_gbps(m, f), r.get("floor"), r.get("verdict")])
        out += ["### Packet size (BlueField-3 Arm, 1 × 100G ingress, drop)", ""]
        out += table(["frame", "rules", "drop Mpps", "drop Gbps (wire)", "floor Mpps", "verdict"],
                     body)
    if out and any(r.get("bench") == "survey" for r in data):
        out += ["*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = "
                "the generator reached its target and the DUT absorbed all of it; **generator** = "
                "the generator could not reach its target, so the DUT's limit is higher than shown.", ""]
    return (["## Summary", ""] + out) if out else []


def write_md(rows, meta, path):
    rig = next((r for r in rows if r.get("bench") == "rig"), {})
    data = [enrich(r) for r in rows if r.get("bench") != "rig"]
    fails = [r for r in data if r.get("verdict") == "FAIL"]
    passes = [r for r in data if r.get("verdict") == "PASS"]
    measured = len(data) - len(passes) - len(fails)
    when = datetime.datetime.fromtimestamp(min((r.get("ts", 0) for r in rows), default=0),
                                           datetime.timezone.utc)
    verdict = ("CALIBRATION RUN (no verdict)" if meta["calibrate"]
               else "PASS" if data and not fails else "FAIL")
    lines = [f"# FastACL hardware bench: {meta['dut']}, {meta['suite']} suite", "",
             f"**{verdict}**: {len(passes)} checks passed, {len(fails)} failed, "
             f"{measured} recorded measurements. {when:%Y-%m-%d %H:%M} UTC.", ""]
    lines += rig_table(rig, meta) + [""]
    lines += summary([r for r in rows if r.get("bench") != "rig"], rig)
    lines += method(rig, {r.get("bench") for r in data})
    for bench, title, cols in SECTIONS:
        group = [r for r in data if r.get("bench") == bench]
        if not group:
            continue
        cols = [(k, h) for k, h in cols if any(fmt(r.get(k)) for r in group)]
        lines += [f"## {title}", "", "| " + " | ".join(h for _, h in cols) + " |",
                  "|" + "---|" * len(cols)]
        lines += ["| " + " | ".join(fmt(r.get(k)) for k, _ in cols) + " |" for r in group]
        lines.append("")
    if not data:
        lines += ["No results were recorded: the bench did not reach a measurement.", ""]
    else:
        lines += legend(data)
    text = "\n".join(lines)
    leak = FORBIDDEN.search(text)
    if leak:
        raise SystemExit(f"report.py: refusing to write a report containing lab data ({leak.group(0)!r})")
    with open(path, "w") as f:
        f.write(text)
    return fails, data


def write_csv(rows, path):
    fields = ["ts", "dut", "gen", "bench", "sweep", "scenario", "rules", "nrules", "attack",
              "frame", "flows", "offered_mpps", "dut_mpps", "tx_mpps", "nic_lost_pct", "cyc_pkt",
              "tuples", "floor", "max_cyc", "max_nic_lost_pct", "max_tuples", "verdict", "detail"]
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            if r.get("bench") != "rig":
                w.writerow({k: fmt(v) for k, v in enrich(r).items()})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--no-gate", action="store_true")
    args = ap.parse_args()

    meta = {
        "dut": os.environ.get("DUT_PROFILE", os.environ.get("PROFILE", "?")),
        "gen": os.environ.get("GEN", "?"),
        "suite": os.environ.get("SUITE", "?"),
        "release": os.environ.get("RELEASE_TAG", "?"),
        "testbench": os.environ.get("TESTBENCH_SHA", "?"),
        "calibrate": args.no_gate,
        "run_url": os.environ.get("RUN_URL", ""),
    }
    rows = load(args.results)
    os.makedirs(args.out_dir, exist_ok=True)
    fails, data = write_md(rows, meta, os.path.join(args.out_dir, "report.md"))
    write_csv(rows, os.path.join(args.out_dir, "results.csv"))
    rig = next((r for r in rows if r.get("bench") == "rig"), {})
    with open(os.path.join(args.out_dir, "meta.json"), "w") as f:
        json.dump({**meta, "rig": rig}, f, indent=2)
    if args.no_gate:
        return 0
    return 1 if fails or not data else 0


if __name__ == "__main__":
    sys.exit(main())
