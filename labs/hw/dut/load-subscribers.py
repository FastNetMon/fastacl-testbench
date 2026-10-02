#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Load one rate-limit rule per subscriber: source 100.64.0.0 + i as a /32,
policed to <rate_bps> with a <burst> token bucket.

    load-subscribers.py <subscribers> <rate_bps> <burst_bytes>
"""

import ipaddress
import sys
import time

sys.path.insert(0, "/src/labs/hw/dut")

from bench import ACTION_RATE_LIMIT, MATCH_SRC_PREFIX, _p2_defaults, _send_batch, connect

BASE = int(ipaddress.IPv4Address("100.64.0.0"))


def entry(i, rate, burst):
    return {
        "order": 10 + i,
        "match": {
            "flags": MATCH_SRC_PREFIX,
            "dst_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
            "dst_prefix_len": 0,
            "src_addr": {"af": 0, "un": {"ip4": str(ipaddress.IPv4Address(BASE + i))}},
            "src_prefix_len": 32,
            "proto": 0,
            "dst_port_min": 0, "dst_port_max": 0,
            "src_port_min": 0, "src_port_max": 0,
            "either_port_min": 0, "either_port_max": 0,
            **_p2_defaults(),
        },
        "action": {"type": ACTION_RATE_LIMIT, "dscp_value": 0, "rate_bps": rate, "burst_bytes": burst},
    }


def main(argv):
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    subs, rate, burst = int(argv[1]), int(argv[2]), int(argv[3])
    vpp = connect("load-subscribers", read_timeout=120)
    try:
        vpp.api.fastacl_rule_del_all()
        t0 = time.time()
        _send_batch(vpp, [entry(i, rate, burst) for i in range(subs)])
        print(f"{subs} subscriber rate-limit rules loaded in {time.time() - t0:.1f}s")
    finally:
        vpp.disconnect()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
