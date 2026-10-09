#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Render /etc/trex_cfg.yaml for any number of ports.

    trex_cfg_multi.py "<pci> <pci> ..." "<w>, <w>, ..." <master> <latency> <socket>

TRex pairs ports in order (0-1, 2-3, ...); the worker list is split evenly
between the pairs.  Prints the worker count per pair, which is TRex's -c.
"""

import sys


def main(argv):
    pcis, workers = argv[1].split(), [w.strip() for w in argv[2].split(",")]
    master, latency, socket = argv[3:6]
    pairs = (len(pcis) + 1) // 2
    per = len(workers) // pairs
    out = [f"- port_limit      : {len(pcis)}",
           "  version         : 2",
           "  interfaces      : [" + ", ".join(f'"{p}"' for p in pcis) + "]",
           "  port_info       :"]
    for i in range(len(pcis)):
        out += [f'    - ip          : "10.{100 + i}.0.1"', f'      default_gw  : "10.{100 + i}.0.2"']
    out += ["  platform        :", f"    master_thread_id  : {master}",
            f"    latency_thread_id : {latency}", "    dual_if           :"]
    for k in range(pairs):
        out += [f"      - socket         : {socket}",
                f"        threads        : [{', '.join(workers[k * per:(k + 1) * per])}]"]
    with open("/etc/trex_cfg.yaml", "w") as f:
        f.write("\n".join(out) + "\n")
    print(per)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
