#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Drive an idle TRex (GEN_IDLE=1) for the generator-pair ceiling test.

    pair_ceiling.py run <ports> <size> <mult> <dst-mac,...> <seconds>

One UDP stream per port in <ports> (comma list of TRex port ids), frame <size>
bytes including FCS, source address incremented over 65,536 values so the
receiver's RSS spreads it, multiplier <mult> per port (e.g. 700mpps).  Traffic
runs for <seconds> and stops; TRex stops a client's streams when it disconnects,
so the client stays connected throughout.  Prints one JSON line with the TRex
transmit rate per port over the last half of the run.
"""

import json
import os
import sys
import time

import _trex_env  # noqa: F401
from trex.stl.api import (STLClient, STLStream, STLPktBuilder, STLTXCont, STLScVmRaw,
                          STLVmFlowVar, STLVmWrFlowVar, STLVmFixIpv4)
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP
from scapy.packet import Raw

STREAMS = int(os.environ.get("PAIR_STREAMS", "1"))
DPORT = int(os.environ.get("PAIR_DPORT", "12"))


def stream(size, dst_mac):
    base = Ether(dst=dst_mac) / IP(src="16.0.0.1", dst="48.0.0.1") / UDP(sport=1025, dport=DPORT)
    pad = max(0, size - 4 - len(base))
    vm = STLScVmRaw([STLVmFlowVar(name="src", min_value=0x10000001, max_value=0x10010000, size=4, op="inc"),
                     STLVmWrFlowVar(fv_name="src", pkt_offset="IP.src"),
                     STLVmFixIpv4(offset="IP")], cache_size=255)
    return STLStream(packet=STLPktBuilder(pkt=base / Raw(b"\x00" * pad), vm=vm), mode=STLTXCont(percentage=100))


def main(argv):
    c = STLClient()
    c.connect()
    try:
        all_ports = list(range(len(c.get_all_ports())))
        ports = [int(p) for p in argv[2].split(",")]
        size, mult, macs, secs = int(argv[3]), argv[4], argv[5].split(","), float(argv[6])
        c.acquire(ports=all_ports, force=True)
        c.stop(ports=all_ports)
        c.remove_all_streams(ports=all_ports)
        for p, mac in zip(ports, macs):
            c.add_streams([stream(size, mac) for _ in range(STREAMS)], ports=[p])
        c.start(ports=ports, mult=mult, force=True)
        time.sleep(secs / 2)
        s1, t1 = c.get_stats(ports=ports), time.time()
        time.sleep(secs / 2)
        s2, t2 = c.get_stats(ports=ports), time.time()
        c.stop(ports=ports)
        print(json.dumps({p: (s2[p]["opackets"] - s1[p]["opackets"]) / (t2 - t1) / 1e6 for p in ports}))
    finally:
        c.disconnect()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
