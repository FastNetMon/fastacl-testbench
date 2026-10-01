#!/usr/bin/env python3
"""Mutate FastACL state through the binary API, from a shell script.

The CLI's mutating commands are a debug convenience and are not synchronised
against the workers, so anything that changes state *while traffic is running*
has to go through the binary API -- which VPP dispatches under the worker
barrier.  bench.sh clears counters and reloads rules between measurement
windows with the generator at line rate, so it calls this instead of vppctl.

    fastacl-api.py clear-counters
    fastacl-api.py per-rule-stats {enable|disable}
    fastacl-api.py del-all
    fastacl-api.py rule-add <order> <dst-prefix> <proto>
"""
import sys

sys.path.insert(0, "/src/labs/hw/dut")
from bench import _p2_defaults, connect


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    cmd = argv[1]
    vpp = connect("fastacl-api")
    try:
        if cmd == "clear-counters":
            reply = vpp.api.fastacl_counters_clear()
        elif cmd == "per-rule-stats":
            reply = vpp.api.fastacl_rule_stats_set(
                enable=argv[2] == "enable")
        elif cmd == "del-all":
            reply = vpp.api.fastacl_rule_del_all()
        elif cmd == "rule-add":
            order, dst, proto = int(argv[2]), argv[3], int(argv[4])
            addr, plen = dst.split("/")
            reply = vpp.api.fastacl_rule_add(
                order=order,
                match={
                    "flags": 0x0001 | 0x0004,
                    "dst_addr": {"af": 0, "un": {"ip4": addr}},
                    "src_addr": {"af": 0, "un": {"ip4": "0.0.0.0"}},
                    "dst_prefix_len": int(plen),
                    "proto": proto,
                    **_p2_defaults(),
                },
                action={"type": 0},
            )
        else:
            print(f"unknown command: {cmd}", file=sys.stderr)
            return 2

        if getattr(reply, "retval", 0) != 0:
            print(f"{cmd}: retval={reply.retval}", file=sys.stderr)
            return 1
        return 0
    finally:
        vpp.disconnect()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
