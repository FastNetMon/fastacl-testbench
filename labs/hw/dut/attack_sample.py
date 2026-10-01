#!/usr/bin/env python3
"""Single-window FastACL sampler used by attack-bench.sh.

Clears the plugin's counters, waits warm_sec, samples for sample_sec,
prints one line:

    <cyc/pkt>   <Mpps>

The output is consumed by attack-bench.sh which prepends the attack
name and renders the table.

Usage:
  python3 attack_sample.py [warm_sec] [sample_sec]
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench

vppctl = bench.vppctl

def _parse_runtime_col(text, node_name, col):
    """Return the average of a numeric column from `show runtime` lines
    matching node_name.  col is the 0-based field index."""
    vals = []
    for line in text.splitlines():
        if node_name in line:
            parts = line.split()
            if len(parts) > col:
                try:
                    vals.append(float(parts[col]))
                except ValueError:
                    pass
    return (sum(vals) / len(vals)) if vals else 0.0

def avg_filter_clocks(text):
    """Pull the average Clocks/Pkt from `show runtime` for fastacl-filter."""
    return _parse_runtime_col(text, "fastacl-filter", 5)

def avg_dpdk_vectors_per_call(text):
    """Pull the average Vectors/Call for dpdk-input (batch size per poll)."""
    return _parse_runtime_col(text, "dpdk-input", 6)

def avg_dpdk_clocks_per_pkt(text):
    """Pull the average Clocks/Pkt for dpdk-input (includes empty-poll amortisation)."""
    return _parse_runtime_col(text, "dpdk-input", 5)

def sum_filter_vectors(text):
    """Sum total vectors processed by fastacl-filter across all workers."""
    total = 0
    for line in text.splitlines():
        if "fastacl-filter" in line:
            parts = line.split()
            if len(parts) > 3:
                try:
                    total += int(parts[3])
                except ValueError:
                    pass
    return total

def main():
    warm = float(sys.argv[1]) if len(sys.argv) > 1 else 4
    sample = float(sys.argv[2]) if len(sys.argv) > 2 else 8

    vpp = bench.connect("attack-sample", read_timeout=15)
    try:
        vpp.api.fastacl_counters_clear()
        time.sleep(warm)

        vppctl("clear runtime")
        time.sleep(sample)

        rt = vppctl("show runtime")
        cyc    = avg_filter_clocks(rt)
        d_vec  = avg_dpdk_vectors_per_call(rt)
        d_clk  = avg_dpdk_clocks_per_pkt(rt)

        rt_vectors = sum_filter_vectors(rt)
        mpps = rt_vectors / sample / 1e6
        print(f"{cyc:>9.0f}  {mpps:>7.1f}"
              f"  dpdk: {d_vec:>5.2f}pkt/call  {d_clk:>6.0f}cyc/pkt")
    finally:
        vpp.disconnect()

if __name__ == "__main__":
    main()
