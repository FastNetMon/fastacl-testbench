#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)
"""Install the same drop rule set in FastACL or in VPP's stock ACL plugin.

  python3 load-rules.py --engine fastacl|acl|fa-acl --n N [--ifaces a,b,...]

N cold rules (UDP to 172.17.x.y/32, never hit) plus one hot rule that drops the
generator's traffic (UDP to 48.0.0.0/16, ports 8000-8255).  With --engine acl the
rules form one ACL applied as input ACL on every sink port.
"""
import argparse
import json
import time

import bench


def rule_set(n):
    cold = [("172.17.%d.%d" % ((i >> 8) & 255, i & 255), 32, 8000, 8255) for i in range(n)]
    return cold + [("48.0.0.0", 16, 8000, 8255)]


def fastacl_entry(order, dst, plen, lo, hi):
    e = bench._dst_entry(order, dst, plen)
    e["match"]["flags"] |= bench.MATCH_PROTO | bench.MATCH_DST_PORT
    e["match"].update(proto=17, dst_port_min=lo, dst_port_max=hi)
    return e


def acl_rule(dst, plen, lo, hi):
    return dict(is_permit=0, src_prefix="0.0.0.0/0", dst_prefix="%s/%d" % (dst, plen), proto=17,
                srcport_or_icmptype_first=0, srcport_or_icmptype_last=65535,
                dstport_or_icmpcode_first=lo, dstport_or_icmpcode_last=hi)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", choices=("fastacl", "acl", "fa-acl"), required=True)
    ap.add_argument("--n", type=int, default=0)
    ap.add_argument("--ifaces", default="")
    ap.add_argument("--no-l4-frag-match", action="store_true")
    a = ap.parse_args()
    vpp = bench.connect("load-rules", read_timeout=600)
    rules = rule_set(a.n)
    if a.no_l4_frag_match:
        bench.vppctl("set acl-plugin l4-match-nonfirst-fragment 0")
    t = time.time()
    if a.engine == "fastacl":
        bench.clear_rules(vpp)
        bench._send_batch(vpp, [fastacl_entry(10 + i, *r) for i, r in enumerate(rules)])
    elif a.engine == "fa-acl":
        acl = vpp.api.acl_add_replace(acl_index=0xFFFFFFFF, tag="bench", count=len(rules),
                                      r=[acl_rule(*r) for r in rules]).acl_index
        bench.vppctl("fastacl acl-bind %d" % acl)
        bench.vppctl("fastacl acl-engine on")
    else:
        acl = vpp.api.acl_add_replace(acl_index=0xFFFFFFFF, tag="bench", count=len(rules),
                                      r=[acl_rule(*r) for r in rules]).acl_index
        names = set(a.ifaces.split(",")) if a.ifaces else None
        for i in vpp.api.sw_interface_dump():
            if names is not None and i.interface_name not in names:
                continue
            if i.interface_name.startswith(("local", "loop")):
                continue
            vpp.api.acl_interface_set_acl_list(sw_if_index=i.sw_if_index, count=1, n_input=1, acls=[acl])
    print(json.dumps({"engine": a.engine, "rules": len(rules), "load_s": round(time.time() - t, 2)}))


if __name__ == "__main__":
    main()
