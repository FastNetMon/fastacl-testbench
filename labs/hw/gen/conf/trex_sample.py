#!/usr/bin/env python3
"""Single-window TRex TX-rate sampler used by attack-bench.sh.

Connects to the running TRex daemon, waits warm_sec for the new attack
to ramp, samples for sample_sec, and prints one number:

    <TX Mpps>

Usage:
  python3 trex_sample.py [warm_sec] [sample_sec]
"""

import os
import sys
import time

import _trex_env
from trex.stl.api import STLClient

def main():
    warm   = float(sys.argv[1]) if len(sys.argv) > 1 else 4
    sample = float(sys.argv[2]) if len(sys.argv) > 2 else 8

    c = STLClient()
    c.connect()
    try:
        time.sleep(warm)

        samples = []
        end = time.monotonic() + sample
        while time.monotonic() < end:
            s = c.get_stats(ports=[0])
            samples.append(s.get(0, {}).get("tx_pps", 0.0))
            time.sleep(0.5)

        mpps = (sum(samples) / len(samples)) / 1e6 if samples else 0.0
        print(f"{mpps:7.1f}")
    finally:
        c.disconnect()

if __name__ == "__main__":
    main()
