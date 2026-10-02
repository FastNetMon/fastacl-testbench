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

import os
import sys

ATTACK_FILE = "/tmp/trex-attack"
def valid_attacks():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from attacks import PROFILES
    return {"udp-rand", "stop", *PROFILES}

def main():
    if len(sys.argv) < 2:
        print("usage: switch.py <attack>|stop", file=sys.stderr)
        return 2
    arg = sys.argv[1]
    valid = valid_attacks()
    if arg not in valid:
        print(f"unknown attack: {arg}; valid: {sorted(valid)}", file=sys.stderr)
        return 1
    rate = sys.argv[2] if len(sys.argv) > 2 else ""
    with open(ATTACK_FILE, "w") as f:
        f.write((f"{arg} {rate}" if rate else arg) + "\n")
    print(f"requested: {arg}{' @ ' + rate if rate else ''}"
          "  (run.py will pick up within ~2 s)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
