#!/usr/bin/env python3
"""Hot-swap the running TRex daemon's attack profile via file hand-off.

Writes the requested attack name to /tmp/trex-attack — run.py polls that
file and reloads streams without dropping its STLClient connection.
This avoids TRex's behaviour of stopping all streams when the owning
client disconnects.

Argv:
  switch.py <attack> [rate]  — write attack (and optional TRex mult, e.g.
                               "110mpps" or "80%") to /tmp/trex-attack
  switch.py stop             — write "stop" so run.py stops traffic
"""

import sys

ATTACK_FILE = "/tmp/trex-attack"
VALID = {"udp-rand", "syn-flood", "ack-flood", "icmp-flood", "frag-flood",
         "fixed-flood", "fixed-flood-31", "fwd-flood-32", "tcp-flows-31",
         "ipv6-flood", "cold-scan", "cold-scan-scatter", "cold-scan-imix",
         "ip6-cold-scan", "reflection-mix", "multivector", "mix-sizes",
         "mix-protos", "mix-udptcp", "mix-burst", "stop"}

def main():
    if len(sys.argv) < 2:
        print("usage: switch.py <attack>|stop", file=sys.stderr)
        return 2
    arg = sys.argv[1]
    if arg not in VALID:
        print(f"unknown attack: {arg}; valid: {sorted(VALID)}", file=sys.stderr)
        return 1
    rate = sys.argv[2] if len(sys.argv) > 2 else ""
    with open(ATTACK_FILE, "w") as f:
        f.write((f"{arg} {rate}" if rate else arg) + "\n")
    print(f"requested: {arg}{' @ ' + rate if rate else ''}"
          "  (run.py will pick up within ~2 s)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
