#!/usr/bin/env python3
"""Load a named rule scenario for the udp-rand benchmark.

Usage:
  python3 load-scenario.py --scenario 5rules-drop
  python3 load-scenario.py --scenario 1m-rules-drop
  python3 load-scenario.py --scenario 0rules

Scenarios:
  5rules-drop              — 5 UDP dport port-range rules covering 8000-8255, DROP
  1m-rules-drop            — ~983K cold dst/24 rules + 5 hot port-range rules, DROP
  1m-rules-drop-ip6        — ~983K cold IPv6 dst/64 rules, DROP
  0rules                   — clear all rules (pass-through baseline)
  5rules-ratelimit-conform — 5 port-range rules, RATE_LIMIT @ 90 Gbps (all conform)
  5rules-ratelimit-exceed  — 5 port-range rules, RATE_LIMIT @ 5 Mbps  (all exceed)

For the rate-limit scenarios the meaningful signal is the plugin's per-rule
conform/exceed counters, not forwarded Mpps — see dut/action_check.py ratelimit, which
the hw-line-rate CI uses to assert the policer engages.
"""

import argparse
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench

def load_5rules_drop(vpp):
    bench.clear_rules(vpp)
    hot = bench._port_hot_entries(5)
    bench._load_rules(vpp, hot, "port-range rules")
    print(f"5rules-drop: {len(hot)} rules loaded.")

def load_1m_rules_drop(vpp):
    bench.clear_rules(vpp)
    cold = bench._cold_entries(999_000)
    n_cold = len(cold)
    hot = bench._port_hot_entries(5, base_order=(n_cold + 1) * 10)
    bench._load_rules(vpp, cold, "cold dst/24 rules")
    bench._load_rules(vpp, hot, "hot port-range rules")
    print(f"1m-rules-drop: {n_cold + len(hot):,} rules loaded ({n_cold:,} cold + {len(hot)} hot).")

def load_nrules_drop(vpp):
    """FASTACL_NRULES rules: cold dst/24 drops plus the 5 hot port-range rules.

    The rule-count axis of the survey: same traffic and tuples at every size, so
    only the table size changes."""
    total = int(os.environ.get("FASTACL_NRULES", "5"))
    bench.clear_rules(vpp)
    cold = bench._cold_entries(max(0, total - 5))
    hot = bench._port_hot_entries(5, base_order=(len(cold) + 1) * 10)
    if cold:
        bench._load_rules(vpp, cold, "cold dst/24 rules")
    bench._load_rules(vpp, hot, "hot port-range rules")
    print(f"nrules-drop: {len(cold) + len(hot):,} rules loaded ({len(cold):,} cold + {len(hot)} hot).")

def load_multivector(vpp):
    """Rule set shaped like a real mitigation policy: 7 distinct mask shapes.

    Pairs with the multivector traffic profile.  See bench._multivector_entries
    for why five attack vectors do not mean five tuples."""
    bench.clear_rules(vpp)
    entries = bench._multivector_entries()
    bench._load_rules(vpp, entries, "multivector policy")
    print(f"multivector: {len(entries):,} rules loaded.")
def load_1m_rules_drop_ip6(vpp):
    """IPv6 twin of 1m-rules-drop: ~983K dst /64 cold rules, DROP.

    All prefix-only, so the tuple takes the compact 16-byte-key bihash and the
    ip6-cold-scan profile can walk it the way cold-scan walks the IPv4 table."""
    bench.clear_rules(vpp)
    cold = bench._ip6_cold_entries(983_040)
    bench._load_rules(vpp, cold, "cold IPv6 dst/64 rules")
    print(f"1m-rules-drop-ip6: {len(cold):,} IPv6 rules loaded.")

def load_1m_rules_drop_proto(vpp):
    """1m-rules-drop with proto=UDP on every cold rule.

    Same traffic and same flow counts as 1m-rules-drop; the only difference is
    that each rule also matches proto, which is what decides whether the tuple
    can use the folded 64-bit compact key."""
    bench.clear_rules(vpp)
    cold = bench._cold_proto_entries(999_000)
    bench._load_rules(vpp, cold, "cold dst/24+proto rules")
    print(f"1m-rules-drop-proto: {len(cold):,} rules loaded.")

def load_tsweep(vpp):
    """Cold /24 table plus FASTACL_TSWEEP_DECOYS extra mask shapes.

    TSS probes every tuple per packet, so this varies the number of tuples while
    holding the matching table -- and therefore the hot working set -- fixed.
    The decoys never match; they cost exactly one probe each."""
    n = int(os.environ.get("FASTACL_TSWEEP_DECOYS", "0"))
    bench.clear_rules(vpp)
    cold = bench._cold_entries(983_040)
    decoys = bench._tshape_decoys(n)
    bench._load_rules(vpp, cold, "cold dst/24 rules")
    if decoys:
        bench._load_rules(vpp, decoys, f"{n} decoy mask shapes")
    print(f"tsweep: {len(cold):,} cold + {len(decoys):,} decoy rules, "
          f"{n + 1} mask shapes total.")

def load_0rules(vpp):
    bench.clear_rules(vpp)
    print("0rules: all rules cleared.")

def _load_5rules_ratelimit(vpp, cir_bps, label):
    bench.clear_rules(vpp)
    action = {"type": bench.ACTION_RATE_LIMIT, "dscp_value": 0,
              "rate_bps": cir_bps, "burst_bytes": 65535}
    hot = bench._port_hot_entries(5, action=action)
    bench._load_rules(vpp, hot, f"rate-limit {label} rules")
    cir_str = (f"{cir_bps / 1e9:g} Gbps" if cir_bps >= 1_000_000_000
               else f"{cir_bps / 1e6:g} Mbps")
    print(f"5rules-ratelimit-{label}: {len(hot)} rules loaded (CIR {cir_str}).")

def load_5rules_ratelimit_conform(vpp):
    _load_5rules_ratelimit(vpp, 90_000_000_000, "conform")

def load_5rules_ratelimit_exceed(vpp):
    _load_5rules_ratelimit(vpp, 5_000_000, "exceed")


SET_NAME = "hwset"
SET_LENGTHS = list(range(10, 25))

# fixed-flood-31 randomises its sources across the SPREAD_TARGETS ranges
# (10.1.0.1-10.1.15.254 and the 10.2/10.3 equivalents).  A country list whose
# prefixes never cover those sources measures the forwarding path instead of
# the filter, so seed the list with prefixes that DO cover them - a realistic
# shape too: a large list of which only part is being hit.
ATTACK_COVERING = [("10.1.0.0", 20), ("10.2.0.0", 20), ("10.3.0.0", 20)]

def _country_prefixes(n_prefixes):
    """n prefixes spread across /10../24 - the shape of a real country list,
    where the prefix-LENGTH diversity is what costs TSS a tuple each.  The
    first few cover the generator's source ranges so traffic actually matches."""
    out = list(ATTACK_COVERING)
    i = 0
    while len(out) < n_prefixes:
        plen = SET_LENGTHS[i % len(SET_LENGTHS)]
        k = i // len(SET_LENGTHS)
        a = 16 + (k // 65536) % 200
        b = (k // 256) % 256
        c = k % 256
        out.append((f"{a}.{b}.{c}.0", plen))
        i += 1
    return out

def load_country_set(vpp, n_prefixes=20000):
    """Country list as a NAMED SET: one rule, one tuple, LPM does the work."""
    bench.clear_rules(vpp)
    bench.vppctl(f"fastacl set destroy {SET_NAME}")
    bench.vppctl(f"fastacl set create {SET_NAME}")

    t0 = time.monotonic()
    for addr, plen in _country_prefixes(n_prefixes):
        rv = vpp.api.fastacl_set_prefix_add_del(
            name=SET_NAME, prefix=f"{addr}/{plen}", is_add=True)
        if rv.retval != 0:
            raise SystemExit(f"set prefix add failed: {rv.retval}")
    dt = time.monotonic() - t0

    out = bench.vppctl(f"fastacl rule add order 10 src-set {SET_NAME} "
                 f"proto 17 action drop")
    if "rule index" not in out:
        raise SystemExit(f"set rule add failed: {out}")

    tuples = bench.vppctl("show fastacl tuples")
    print(f"country-set-drop: {n_prefixes:,} prefixes over {len(SET_LENGTHS)} "
          f"lengths loaded in {dt:.1f}s; {tuples.splitlines()[0]}")

def load_country_rules(vpp, n_prefixes=20000):
    """Same list as INDIVIDUAL RULES - the TSS baseline this feature replaces.
    One tuple per distinct prefix length, probed on every packet."""
    bench.clear_rules(vpp)
    entries = []
    for i, (addr, plen) in enumerate(_country_prefixes(n_prefixes)):
        entries.append({
            "order": 10 + i * 10,
            "match": {
                "flags": bench.MATCH_SRC_PREFIX | bench.MATCH_PROTO,
                "dst_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
                "dst_prefix_len": 0,
                "src_addr": {"af": 0, "un": {"ip4": addr}},
                "src_prefix_len": plen,
                "proto": 17,
                "dst_port_min": 0, "dst_port_max": 0,
                "src_port_min": 0, "src_port_max": 0,
                "either_port_min": 0, "either_port_max": 0,
                **bench._p2_defaults(),
            },
            "action": {"type": 0},
        })
    bench._load_rules(vpp, entries, "country prefix rules")
    tuples = bench.vppctl("show fastacl tuples")
    print(f"country-rules-drop: {n_prefixes:,} rules; {tuples.splitlines()[0]}")

SCENARIOS = {
    "5rules-drop":              load_5rules_drop,
    "1m-rules-drop":            load_1m_rules_drop,
    "nrules-drop":              load_nrules_drop,
    "multivector":              load_multivector,
    "tsweep":                   load_tsweep,
    "1m-rules-drop-proto":      load_1m_rules_drop_proto,
    "0rules":                   load_0rules,
    "5rules-ratelimit-conform": load_5rules_ratelimit_conform,
    "5rules-ratelimit-exceed":  load_5rules_ratelimit_exceed,
    '1m-rules-drop-ip6': load_1m_rules_drop_ip6,
    "country-set-drop":         load_country_set,
    "country-rules-drop":       load_country_rules,
}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True, choices=list(SCENARIOS))
    args = parser.parse_args()

    vpp = bench.connect()
    try:
        SCENARIOS[args.scenario](vpp)
    finally:
        vpp.disconnect()

if __name__ == "__main__":
    main()
