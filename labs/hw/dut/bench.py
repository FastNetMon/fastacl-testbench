#!/usr/bin/env python3
"""FastACL performance benchmark — TSS classifier, scaling rule count.

The data plane uses TSS (Tuple Space Search): rules are grouped by mask
shape and looked up via per-tuple hash probes.  Lookup cost is O(T) hash
probes where T = number of distinct tuples — independent of total rule
count.  This bench verifies that property by sweeping rule count from
5 to 1 000 000 with the same handful of tuples.

Scenarios (run in order):
  ref       5 hot rules                                  — 1 tuple
  baseline  100 hot rules                                — 1 tuple
  10k       10 000 rules (9 900 cold + 100 hot)          — 2 tuples
  1M        1 000 000 rules (999 000 cold + 1 000 hot)   — 2 tuples

Hot rules:
  5 / 100  — UDP dport ranges covering 8000-8255 (TRex spread traffic).
  1 000    — src /32 prefix rules for TRex spread src IPs (10.1-3.x.x).

Cold rules: dst-prefix /24 rules in 1-15.x.x.x (never matched by TRex).
With TSS, "cold" rules don't slow lookup — they live in their own tuple
and a packet whose dst /24 isn't present takes a single missed hash probe.

Batch API: uses fastacl_rule_add_batch (N rules per call), which sorts and
indexes the whole table once at the end of the call.  Batch loading achieves
~25 000 rules/sec vs ~110/sec single-call.

Usage:
  docker exec <dut> python3 /src/labs/hw/dut/bench.py
"""

import glob
import os
import subprocess
import sys
import time

API_SOCKET = os.environ.get("FASTACL_API_SOCKET", "/run/vpp/api.sock")
CLI_SOCKET = "/run/vpp/cli.sock"

MATCH_DST_PREFIX = 0x0001
MATCH_SRC_PREFIX = 0x0002
MATCH_PROTO      = 0x0004
MATCH_DST_PORT   = 0x0008
MATCH_EITHER_PORT = 0x0020
MATCH_SRC_PORT   = 0x0010
MATCH_IS_IP6     = 0x8000

ACTION_DROP       = 0
ACTION_DSCP_MARK  = 1
ACTION_RATE_LIMIT = 2

_EMPTY_FLEX = {"offset": 0, "len": 0, "op": 0, "mask": 0, "value": 0}

def _p2_defaults():
    """Phase 2 match fields — zero/empty defaults for rules that don't use them."""
    return {
        "icmp_type": 0, "icmp_code": 0,
        "tcp_flags_value": 0, "tcp_flags_mask": 0,
        "pkt_len_min": 0, "pkt_len_max": 0,
        "dscp": 0,
        "fragment_flags": 0, "fragment_mask": 0,
        "n_flex_matches": 0,
        "flex_matches": [_EMPTY_FLEX] * 4,
    }

SPREAD_DPORT_MIN   = 8000
SPREAD_DPORT_MAX   = 8255
SPREAD_DPORT_RANGE = SPREAD_DPORT_MAX - SPREAD_DPORT_MIN + 1
TREX_SRC_PREFIXES = [("10.1", 0, 15), ("10.2", 0, 15), ("10.3", 0, 15)]

WARM_SEC    = 3
SAMPLE_SEC  = 10
BATCH_SIZE  = 4096

def vppctl(cmd, timeout=60):
    r = subprocess.run(["vppctl", "-s", CLI_SOCKET, cmd],
                       capture_output=True, text=True, timeout=timeout)
    return r.stdout.strip()

def connect(name="bench", read_timeout=60):
    from vpp_papi import VPPApiClient
    build_json = os.path.join(os.environ.get("FASTACL_BUILD_DIR", "/src/build"),
                              "src/plugins/fastacl/fastacl.api.json")
    have_build = os.path.isfile(build_json)
    apifiles = [f for f in glob.glob("/usr/share/vpp/api/**/*.json", recursive=True)
                if not (have_build and os.path.basename(f) == "fastacl.api.json")]
    if have_build:
        apifiles.append(build_json)
    vpp = VPPApiClient(apifiles=apifiles, server_address=API_SOCKET,
                       read_timeout=read_timeout)
    vpp.connect(name)
    return vpp

def _has_batch_api(vpp):
    return hasattr(vpp.api, "fastacl_rule_add_batch")

def _send_batch(vpp, entries):
    """Send a list of rule-entry dicts using batch API (or single-rule fallback)."""
    if _has_batch_api(vpp):
        for i in range(0, len(entries), BATCH_SIZE):
            chunk = entries[i:i + BATCH_SIZE]
            rv = vpp.api.fastacl_rule_add_batch(count=len(chunk), rules=chunk)
            if rv.retval != 0:
                raise RuntimeError(
                    f"fastacl_rule_add_batch failed: retval={rv.retval} "
                    f"after {rv.n_added} rules in chunk starting at {i}"
                )
    else:
        for e in entries:
            vpp.api.fastacl_rule_add(
                order=e["order"], match=e["match"], action=e["action"]
            )

def clear_rules(vpp):
    vppctl("fastacl rule del all")
    vpp.api.fastacl_counters_clear()

def _dst_entry(order, dst_ip, dst_len):
    return {
        "order": order,
        "match": {
            "flags": MATCH_DST_PREFIX,
            "dst_addr": {"af": 0, "un": {"ip4": dst_ip}},
            "dst_prefix_len": dst_len,
            "src_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
            "src_prefix_len": 0,
            "proto": 0,
            "dst_port_min": 0, "dst_port_max": 0,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": {"type": 0},
    }

def _port_entry(order, dport_min, dport_max, action=None):
    return {
        "order": order,
        "match": {
            "flags": MATCH_PROTO | MATCH_DST_PORT,
            "dst_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
            "dst_prefix_len": 0,
            "src_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
            "src_prefix_len": 0,
            "proto": 17,
            "dst_port_min": dport_min, "dst_port_max": dport_max,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": action if action is not None else {"type": ACTION_DROP},
    }

def _ip6_dst_port_entry(order, dst_ip6, dst_len, dport_min, dport_max,
                        action=None):
    """IPv6 dst-prefix + UDP proto + dport-range rule."""
    return {
        "order": order,
        "match": {
            "flags": MATCH_DST_PREFIX | MATCH_PROTO | MATCH_DST_PORT | MATCH_IS_IP6,
            "dst_addr": {"af": 1, "un": {"ip6": dst_ip6}},
            "dst_prefix_len": dst_len,
            "src_addr": {"af": 1, "un": {"ip6": "::"}},
            "src_prefix_len": 0,
            "proto": 17,
            "dst_port_min": dport_min, "dst_port_max": dport_max,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": action if action is not None else {"type": ACTION_DROP},
    }

def _ip6_dst128_entry(order, dst_ip6, action=None):
    """IPv6 dst /128 prefix-only rule — unique TSS key, no proto/port.
    Matches all traffic to one specific dst address."""
    return {
        "order": order,
        "match": {
            "flags": MATCH_DST_PREFIX | MATCH_IS_IP6,
            "dst_addr": {"af": 1, "un": {"ip6": dst_ip6}},
            "dst_prefix_len": 128,
            "src_addr": {"af": 1, "un": {"ip6": "::"}},
            "src_prefix_len": 0,
            "proto": 0,
            "dst_port_min": 0, "dst_port_max": 0,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": action if action is not None else {"type": ACTION_DROP},
    }

def _src32_entry(order, src_ip):
    return {
        "order": order,
        "match": {
            "flags": MATCH_SRC_PREFIX,
            "dst_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
            "dst_prefix_len": 0,
            "src_addr": {"af": 0, "un": {"ip4": src_ip}},
            "src_prefix_len": 32,
            "proto": 0,
            "dst_port_min": 0, "dst_port_max": 0,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": {"type": 0},
    }

def _ip6_port_hot_entries(n, base_order=10, action=None):
    """n IPv6 port-range hot rules covering SPREAD_DPORT_MIN..MAX.
    All rules share dst 2001:db8:ff::/48 + proto → same TSS key → chain of N.
    Kept for reference; _ip6_prefix_hot_entries is the correct TSS scenario."""
    entries = []
    for i in range(n):
        lo = SPREAD_DPORT_MIN + int(i * SPREAD_DPORT_RANGE / n)
        hi = SPREAD_DPORT_MIN + int((i + 1) * SPREAD_DPORT_RANGE / n) - 1
        entries.append(_ip6_dst_port_entry(
            base_order + i * 10, "2001:db8:ff::", 48, lo, hi, action=action))
    return entries

def _ip6_dst64_entry(order, dst_ip6, action=None):
    """IPv6 dst /64 prefix-only rule — no proto, no src, no ports.

    Prefix-only is what makes the tuple eligible for the compact 16-byte-key
    bihash: the whole key lives in dst[0..1], so the entry sits inside the
    bucket instead of a separate value page."""
    return {
        "order": order,
        "match": {
            "flags": MATCH_DST_PREFIX | MATCH_IS_IP6,
            "dst_addr": {"af": 1, "un": {"ip6": dst_ip6}},
            "dst_prefix_len": 64,
            "src_addr": {"af": 1, "un": {"ip6": "::"}},
            "src_prefix_len": 0,
            "proto": 0,
            "dst_port_min": 0, "dst_port_max": 0,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": action if action is not None else {"type": ACTION_DROP},
    }

def _ip6_cold_entries(n_cold, start_order=10):
    """n_cold IPv6 dst /64 cold rules at 2001:db8:HH:LL::/64.

    The IPv6 twin of _cold_entries: rule i covers 2001:db8:{i>>16}:{i&0xffff}::/64,
    and the ip6-cold-scan profile randomises those same two hextets, so F flows
    probe exactly F distinct buckets.  Every rule is dst-prefix-only, so the whole
    table lands in the compact table."""
    entries = []
    order = start_order
    for i in range(n_cold):
        dst = f"2001:db8:{(i >> 16) & 0xffff:x}:{i & 0xffff:x}::"
        entries.append(_ip6_dst64_entry(order, dst, action=None))
        order += 10
    return entries

def _ip6_prefix_hot_entries(n, base_order=10, action=None):
    """n IPv6 dst-/128 rules — each matches a distinct TRex dst IP.

    TRex ipv6-flood cycles its dst last byte from 1..128 (attacks.py
    IPV6_DST_MAX), so rule i matches dst 2001:db8:ff::{i+1}/128.
    Every rule gets a unique TSS bihash key → no collision chains → O(1)
    lookup regardless of N.  This is the correct scenario for demonstrating
    TSS O(tuples) behaviour with IPv6 traffic.
    """
    entries = []
    for i in range(n):
        dst = f"2001:db8:ff::{i + 1}"
        entries.append(_ip6_dst128_entry(base_order + i * 10, dst, action=action))
    return entries

def _port_hot_entries(n, base_order=10, action=None):
    """n port-range hot rules covering SPREAD_DPORT_MIN..MAX."""
    entries = []
    for i in range(n):
        lo = SPREAD_DPORT_MIN + int(i * SPREAD_DPORT_RANGE / n)
        hi = SPREAD_DPORT_MIN + int((i + 1) * SPREAD_DPORT_RANGE / n) - 1
        entries.append(_port_entry(base_order + i * 10, lo, hi, action=action))
    return entries

def _src_hot_entries(n, base_order):
    """n src /32 hot rules from TRex's random src IP ranges."""
    per = [n // 3 + (1 if i < n % 3 else 0) for i in range(3)]
    entries = []
    order = base_order
    for (pfx, b_min, b_max), count in zip(TREX_SRC_PREFIXES, per):
        added = 0
        for b in range(b_min, b_max + 1):
            for c in range(1, 255):
                if added >= count:
                    break
                entries.append(_src32_entry(order, f"{pfx}.{b}.{c}"))
                order += 10
                added += 1
            if added >= count:
                break
    return entries

def _cold_entries(n_cold, start_order=10):
    """n_cold dst /24 cold rules in 1-15.x.x.x — never matched by TRex."""
    entries = []
    count = 0
    order = start_order
    for a in range(1, 16):
        for b in range(256):
            for c in range(256):
                if count >= n_cold:
                    break
                entries.append(_dst_entry(order, f"{a}.{b}.{c}.0", 24))
                count += 1
                order += 10
            if count >= n_cold:
                break
        if count >= n_cold:
            break
    return entries

def _dst_proto_entry(order, dst_ip, dst_len, proto=17):
    """dst-prefix + proto rule, no src prefix.

    The shape that exercises the folded compact key: src is absent so key[0]'s
    high half is free, and proto folds into it instead of forcing the wide
    24-byte table."""
    e = _dst_entry(order, dst_ip, dst_len)
    e["match"]["flags"] = MATCH_DST_PREFIX | MATCH_PROTO
    e["match"]["proto"] = proto
    return e

def _cold_proto_entries(n_cold, start_order=10):
    """_cold_entries with proto=UDP added to every rule."""
    entries = _cold_entries(n_cold, start_order=start_order)
    for e in entries:
        e["match"]["flags"] = MATCH_DST_PREFIX | MATCH_PROTO
        e["match"]["proto"] = 17
    return entries

_TSHAPES = [
    (MATCH_DST_PREFIX,                    23,  0),
    (MATCH_DST_PREFIX,                    22,  0),
    (MATCH_DST_PREFIX,                    21,  0),
    (MATCH_DST_PREFIX,                    20,  0),
    (MATCH_SRC_PREFIX,                     0, 24),
    (MATCH_SRC_PREFIX,                     0, 16),
    (MATCH_DST_PREFIX | MATCH_PROTO,      24,  0),
    (MATCH_DST_PREFIX | MATCH_PROTO,      20,  0),
    (MATCH_DST_PREFIX | MATCH_SRC_PREFIX, 24, 24),
    (MATCH_DST_PREFIX | MATCH_SRC_PREFIX, 20, 16),
    (MATCH_DST_PREFIX | MATCH_DST_PORT,   24,  0),
    (MATCH_DST_PREFIX | MATCH_DST_PORT,   20,  0),
    (MATCH_DST_PREFIX,                    18,  0),
    (MATCH_DST_PREFIX,                    17,  0),
    (MATCH_DST_PREFIX,                    16,  0),
]

def _tshape_decoys(n_shapes, rules_each=1000, start_order=9_000_000):
    """n_shapes decoy tuples x rules_each rules, none of which can ever match.

    Decoy addresses live in 100-115.x, well clear of the 1-15.x cold table the
    traffic walks, so these cost exactly one probe per packet each and nothing
    else."""
    if n_shapes <= 0:
        return []
    assert n_shapes <= len(_TSHAPES), f"only {len(_TSHAPES)} decoy shapes defined"
    entries = []
    order = start_order
    for si in range(n_shapes):
        flags, dplen, splen = _TSHAPES[si]
        base_a = 100 + si
        for i in range(rules_each):
            e = _dst_entry(order, f"{base_a}.{(i >> 8) & 0xff}.{i & 0xff}.0", 24)
            m = e["match"]
            m["flags"] = flags
            if flags & MATCH_DST_PREFIX:
                m["dst_prefix_len"] = dplen
            else:
                m["dst_addr"] = {"af": 0, "un": {"ip4": "0.0.0.0"}}
                m["dst_prefix_len"] = 0
            if flags & MATCH_SRC_PREFIX:
                m["src_addr"] = {"af": 0, "un": {"ip4": f"{base_a}.{(i >> 8) & 0xff}.{i & 0xff}.0"}}
                m["src_prefix_len"] = splen
            if flags & MATCH_PROTO:
                m["proto"] = 6
            if flags & MATCH_DST_PORT:
                m["dst_port_min"] = 20000 + si
                m["dst_port_max"] = 20000 + si
            entries.append(e)
            order += 10
    return entries

def _multivector_entries(n_cold=900_000, per_shape=10_000):
    """A rule set shaped like a real mitigation policy, not a benchmark.

    Five attack vectors do NOT automatically mean five tuples -- TSS groups by
    mask SHAPE, so TCP and ICMP rules that both match dst-prefix+proto share one
    tuple whatever their proto VALUES are.  Shape count grows with field
    COMBINATIONS, which is what an operator actually accumulates:

      1  dst /24                       the carpet-bomb drop table
      2  dst /24 + proto               per-protocol drops (TCP, ICMP, UDP)
      3  dst /24 + proto + src-port    reflection filters (src port = service)
      4  dst /24 + proto + dst-port    service floods
      5  dst /16                       whole-block drops
      6  src /24                       attacker blocklist
      7  dst /24 + proto + either-port catch-all port rules

    Seven shapes, which docs/tuple-count-sweep.csv puts squarely in the region
    where shape count binds before flow count does."""
    entries = []
    order = 10
    for e in _cold_entries(n_cold, start_order=order):
        entries.append(e)
    order = 8_000_000

    def _mk(flags, plen=24, **kw):
        nonlocal order
        for i in range(per_shape):
            a = 20 + (i >> 16) % 10
            e = _dst_entry(order, f"{a}.{(i >> 8) & 0xff}.{i & 0xff}.0", plen)
            m = e["match"]; m["flags"] = flags
            m.update(kw)
            entries.append(e)
            order += 10

    _mk(MATCH_DST_PREFIX | MATCH_PROTO, proto=6)
    _mk(MATCH_DST_PREFIX | MATCH_PROTO | MATCH_SRC_PORT, proto=17,
        src_port_min=1900, src_port_max=1900)
    _mk(MATCH_DST_PREFIX | MATCH_PROTO | MATCH_DST_PORT, proto=6,
        dst_port_min=80, dst_port_max=80)
    _mk(MATCH_DST_PREFIX, plen=16)
    for i in range(per_shape):
        e = _dst_entry(order, "0.0.0.0", 0)
        m = e["match"]; m["flags"] = MATCH_SRC_PREFIX
        m["dst_prefix_len"] = 0
        m["src_addr"] = {"af": 0, "un": {"ip4": f"30.{(i >> 8) & 0xff}.{i & 0xff}.0"}}
        m["src_prefix_len"] = 24
        entries.append(e); order += 10
    _mk(MATCH_DST_PREFIX | MATCH_PROTO | MATCH_EITHER_PORT, proto=17,
        either_port_min=53, either_port_max=53)
    return entries

def _load_rules(vpp, entries, label, dot_every=5000):
    n = len(entries)
    sys.stdout.write(f"  Loading {n:,} {label}")
    sys.stdout.flush()
    t0 = time.monotonic()
    for i in range(0, n, BATCH_SIZE):
        chunk = entries[i:i + BATCH_SIZE]
        _send_batch(vpp, chunk)
        if (i + BATCH_SIZE) % dot_every < BATCH_SIZE:
            sys.stdout.write(".")
            sys.stdout.flush()
    elapsed = time.monotonic() - t0
    rate = n / elapsed if elapsed > 0 else 0
    print(f" done  ({elapsed:.1f}s, {rate:,.0f} rules/sec)")

def ip6_input_vectors():
    """Return total vectors processed by ip6-input since last clear runtime."""
    out = vppctl("show runtime")
    for line in out.splitlines():
        if "ip6-input" in line:
            parts = line.split()
            if len(parts) >= 7:
                try:
                    return int(parts[3])
                except (ValueError, IndexError):
                    pass
    return 0

def count_hit_rules(vpp):
    return int(vpp.api.fastacl_counters_get().n_hit_rules)

def rule_action_stats(vpp):
    """Return (total_packets, total_conform, total_exceed) summed across all rules."""
    pkts = conform = exceed = 0
    for r in vpp.api.fastacl_rule_dump():
        pkts    += int(r.packet_count)
        conform += int(r.conform_count)
        exceed  += int(r.exceed_count)
    return pkts, conform, exceed

def sample(vpp, label, n_hot, window=SAMPLE_SEC):
    """Clear counters+runtime, sample for window s, return (cyc, mpps, n_hit)."""
    vpp.api.fastacl_counters_clear()
    vppctl("clear runtime")
    sys.stdout.write(f"  Sampling {window} s [{label}]")
    sys.stdout.flush()
    time.sleep(window)
    print()

    out = vppctl("show runtime")
    cyc_vals = []
    for line in out.splitlines():
        if "fastacl-filter" in line:
            parts = line.split()
            if len(parts) >= 6:
                try:
                    cyc_vals.append(float(parts[5]))
                except ValueError:
                    pass
    avg_cyc = sum(cyc_vals) / len(cyc_vals) if cyc_vals else 0

    c = vpp.api.fastacl_counters_get()
    mpps = int(c.total_processed) / window / 1e6
    n_hit = count_hit_rules(vpp)
    return avg_cyc, mpps, n_hit

def _fmt_hit(n_hit, n_hot):
    return f"{n_hit}/{n_hot}"

def run_scenario(vpp, label, n_hot, cold_entries, hot_entries):
    """Load cold+hot rules, sample, return (label, cyc, mpps, n_hit).
    With TSS the rule order doesn't affect lookup cost — placing hot rules
    at the end of the cold list is just a load-time convention. """
    clear_rules(vpp)
    n_cold = len(cold_entries) if cold_entries else 0
    if cold_entries:
        _load_rules(vpp, cold_entries, "cold rules")
    _load_rules(vpp, hot_entries, "hot rules")
    n_tuples = vppctl("show fastacl tuples").splitlines()[0]
    print(f"  {n_tuples}")
    time.sleep(WARM_SEC)
    cyc, mpps, n_hit = sample(vpp, label, n_hot)
    print(f"  Rules hit: {_fmt_hit(n_hit, n_hot)}")
    return label, cyc, mpps, n_hit

def main():
    vpp = connect()
    batch_ok = _has_batch_api(vpp)
    print(f"FastACL benchmark  (batch API: {'YES' if batch_ok else 'NO — single-call fallback'})")
    print()
    results = []

    print("[5 hot rules — single port-range tuple]")
    clear_rules(vpp)
    hot5 = _port_hot_entries(5)
    _load_rules(vpp, hot5, "hot rules")
    print(f"  {vppctl('show fastacl tuples').splitlines()[0]}")
    time.sleep(WARM_SEC)
    cyc, mpps, n_hit = sample(vpp, "5 rules", 5)
    print(f"  Rules hit: {_fmt_hit(n_hit, 5)}")
    results.append(("5 hot rules", cyc, mpps, n_hit, 5))

    n_cold_1k = 900
    n_hot_1k  = 100
    print(f"\n[1 000 rules — 2 tuples (900 cold dst /24 + 100 hot port-range)]")
    cold1k = _cold_entries(n_cold_1k)
    hot_for_1k = _port_hot_entries(n_hot_1k, base_order=(n_cold_1k + 1) * 10)
    label, cyc, mpps, n_hit = run_scenario(
        vpp, "1000 rules", n_hot_1k, cold1k, hot_for_1k)
    results.append((label, cyc, mpps, n_hit, n_hot_1k))

    n_cold_1m = 999_000
    n_hot_1m  = 1_000
    print(f"\n  Pre-building {n_cold_1m:,} cold entries (this takes a moment)...")
    cold1m = _cold_entries(n_cold_1m)
    hot_for_1m = _src_hot_entries(n_hot_1m, base_order=(n_cold_1m + 1) * 10)

    print("\n[1 000 000 rules — 2 tuples (cold dst /24 + hot src /32)]")
    label, cyc, mpps, n_hit = run_scenario(
        vpp, "1M rules", n_hot_1m, cold1m, hot_for_1m)
    results.append((label, cyc, mpps, n_hit, n_hot_1m))

    print("\n[Actions bench — 5 port-range rules, 3 action types]")
    print("Measures per-packet overhead vs baseline drop action.")

    action_results = []
    action_scenarios = [
        ("drop (baseline)",
         None,
         None),
        ("dscp-mark (EF=46, CONTINUE)",
         {"type": ACTION_DSCP_MARK, "dscp_value": 46,
          "rate_bps": 0, "burst_bytes": 0},
         None),
        ("rate-limit conform (90 Gbps, all conform)",
         {"type": ACTION_RATE_LIMIT, "dscp_value": 0,
          "rate_bps": 90_000_000_000, "burst_bytes": 65535},
         "conform"),
        ("rate-limit exceed (1 Gbps, all exceed → drop)",
         {"type": ACTION_RATE_LIMIT, "dscp_value": 0,
          "rate_bps": 1_000_000_000, "burst_bytes": 65535},
         "exceed"),
    ]

    for label, action, rl_mode in action_scenarios:
        clear_rules(vpp)
        entries = _port_hot_entries(5, action=action)
        _load_rules(vpp, entries, f"{label} rules")
        time.sleep(WARM_SEC)
        cyc, mpps, n_hit = sample(vpp, label, 5)
        pkts, conform, exceed = rule_action_stats(vpp)
        extra = ""
        if rl_mode == "conform" and pkts > 0:
            extra = f"  conform={100*conform/pkts:.0f}%"
        elif rl_mode == "exceed" and pkts > 0:
            extra = f"  exceed={100*exceed/pkts:.0f}%"
        action_results.append((label, cyc, mpps, extra))
        print(f"  Rules hit: {_fmt_hit(n_hit, 5)}{extra}")

    print("\n[IPv6 bench — TSS direct]")
    print("Requires TRex running with TREX_ATTACK=ipv6-flood.")

    ip6_results = []
    clear_rules(vpp)
    vppctl("clear runtime")
    time.sleep(WARM_SEC)
    ip6_vec = ip6_input_vectors()
    if ip6_vec == 0:
        print("  SKIP: ip6-input processing 0 vectors — is TRex sending IPv6?")
        print("        Re-run with TREX_ATTACK=ipv6-flood on flame.")
    else:
        print(f"  IPv6 traffic detected ({ip6_vec:,} vectors in {WARM_SEC}s warm period)")

        for n_ip6 in (5, 100):
            label = f"{n_ip6} IPv6 rules"
            print(f"\n[{n_ip6} IPv6 rules — dst /128 per rule, 1 TSS tuple]")
            clear_rules(vpp)
            entries = _ip6_prefix_hot_entries(n_ip6)
            _load_rules(vpp, entries, "IPv6 hot rules")
            n_ip6_rules = vppctl("show fastacl tuples").splitlines()[0]
            print(f"  {n_ip6_rules}")
            time.sleep(WARM_SEC)
            cyc, mpps, n_hit = sample(vpp, label, n_ip6)
            print(f"  Rules hit: {_fmt_hit(n_hit, n_ip6)}")
            ip6_results.append((label, cyc, mpps, n_hit, n_ip6))

    clear_rules(vpp)
    _send_batch(vpp, hot5)
    vpp.disconnect()

    base_cyc = results[0][1]
    print()
    print("=" * 86)
    print(f"  {'Scenario':<42}  {'cyc/pkt':>8}  {'Mpps':>6}  {'hit':>10}  {'vs ref':>7}")
    print(f"  {'-'*42}  {'-'*8}  {'-'*6}  {'-'*10}  {'-'*7}")
    for label, cyc, mpps, n_hit, n_hot in results:
        vs = f"{cyc/base_cyc:.1f}x" if base_cyc else "-"
        hit_s = _fmt_hit(n_hit, n_hot)
        print(f"  {label:<42}  {cyc:>8.0f}  {mpps:>6.1f}  {hit_s:>10}  {vs:>7}")
    print("=" * 86)
    print()
    print("Key:")
    print("  5 rules       — minimum cost: 1 tuple, 1 hash probe")
    print("  1000 rules    — adds a 2nd tuple (cold dst /24); cold tuple is a")
    print("                  hash miss for TRex traffic, near-zero overhead")
    print("  1M rules      — same 2 tuples; lookup cost should be flat vs 1k")
    print("                  (TSS is O(tuples), not O(rules))")
    print()

    if ip6_results:
        print()
        print("=" * 86)
        print(f"  {'IPv6 scenario (TSS direct)':<42}  {'cyc/pkt':>8}  {'Mpps':>6}  {'hit':>10}")
        print(f"  {'-'*42}  {'-'*8}  {'-'*6}  {'-'*10}")
        for label, cyc, mpps, n_hit, n_hot in ip6_results:
            hit_s = _fmt_hit(n_hit, n_hot)
            print(f"  {label:<42}  {cyc:>8.0f}  {mpps:>6.1f}  {hit_s:>10}")
        print("=" * 86)
        print()
        print("Key:")
        print("  Rules: distinct dst /128 per rule → unique TSS key, no chains.")
        print("  Cost should be flat vs rule count (O(tuples)=O(1) since 1 tuple).")

    drop_cyc = action_results[0][1] if action_results else 0
    print("=" * 78)
    print(f"  {'Action scenario':<42}  {'cyc/pkt':>8}  {'Mpps':>6}  {'vs drop':>8}")
    print(f"  {'-'*42}  {'-'*8}  {'-'*6}  {'-'*8}")
    for label, cyc, mpps, extra in action_results:
        vs = f"{cyc/drop_cyc:.2f}x" if drop_cyc else "-"
        suffix = extra.strip()
        print(f"  {label:<42}  {cyc:>8.0f}  {mpps:>6.1f}  {vs:>8}"
              + (f"  ({suffix})" if suffix else ""))
    print("=" * 78)
    print()
    print("Key:")
    print("  drop           — baseline; no header modification, packet discarded")
    print("  dscp-mark      — 1 byte TOS write + incremental checksum; packet passes")
    print("  rate-limit c   — token bucket refill + compare; packet passes (conform)")
    print("  rate-limit e   — same arithmetic; packet dropped (exceed)")

def load_1k(vpp):
    """Load the 1000-rule scenario: 900 cold dst/24 + 100 hot port-range."""
    clear_rules(vpp)
    cold = _cold_entries(900)
    hot  = _port_hot_entries(100, base_order=9010)
    _load_rules(vpp, cold, "cold rules")
    _load_rules(vpp, hot,  "hot rules")
    print("1000 DROP rules loaded and indexed.")

def load_984k(vpp):
    """Load ~984K rules: 983040 cold dst/24 + 1000 hot src/32."""
    n_cold = 999_000
    n_hot  = 1_000
    print("Clearing existing rules...")
    vppctl("fastacl clear")
    print(f"Pre-building {n_cold:,} cold entries...")
    cold = _cold_entries(n_cold)
    hot  = _src_hot_entries(n_hot, base_order=(len(cold) + 1) * 10)
    _load_rules(vpp, cold, "cold dst/24 rules")
    _load_rules(vpp, hot,  "hot src/32 rules")
    print(f"Loaded {len(cold) + len(hot):,} rules ({len(cold):,} cold + {len(hot):,} hot). Ready.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) == 2 and sys.argv[1] == "--load":
        print("Usage: bench.py --load <1k|984k>")
        sys.exit(1)
    if len(sys.argv) == 3 and sys.argv[1] == "--load":
        vpp = connect()
        try:
            if sys.argv[2] == "1k":
                load_1k(vpp)
            elif sys.argv[2] == "984k":
                load_984k(vpp)
            else:
                print(f"Unknown load target: {sys.argv[2]}  (use 1k or 984k)")
                sys.exit(1)
        finally:
            vpp.disconnect()
    else:
        main()
