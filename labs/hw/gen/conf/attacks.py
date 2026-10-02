#!/usr/bin/env python3
"""TRex stateless attack-profile library — FastACL hw lab.

Each builder function returns a list of STLStream objects that, together,
generate one class of DDoS-like traffic.  Selected by the TREX_ATTACK env
var read in run.py.

Profiles cover the RFC 9411 / NetSecOPEN attack types that don't need
spoofed-victim semantics:
  udp-rand    — random src IP + random dport UDP flood (current default)
  syn-flood   — TCP SYN flood, random src, fixed dst:80
  ack-flood   — TCP ACK flood, random src, fixed dst:80
  icmp-flood  — ICMP echo flood, random src
  frag-flood  — IP-fragmented UDP, random src — exercises frag-handling
                upstream of the ACL filter

Source-IP randomization is identical across profiles (10.1-3.0.0/16,
matching the rule sets in dut/bench.py) so the rule-hit semantics stay
comparable; only the L3/L4 protocol headers differ.
"""

import os
import socket
import struct

SENDER_IP   = os.environ.get("SENDER_IP",    "10.0.1.1")
SENDER_MAC  = os.environ.get("SENDER_MAC", "02:00:00:00:00:01")
DUT_MAC     = os.environ.get("DUT_LEFT_MAC", "02:00:00:00:00:02")

import _trex_env
from trex.stl.api import (STLStream, STLTXCont, STLTXSingleBurst,
                          STLPktBuilder,
                          STLVmFlowVar, STLVmWrFlowVar, STLScVmRaw,
                          STLVmFixIpv4)
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP, TCP, ICMP
from scapy.packet import Raw

SPREAD_TARGETS = [
    ("spread-10",  "10.0.2.1",     "10.1.0.1", "10.1.15.254"),
    ("spread-198", "198.51.100.1", "10.2.0.1", "10.2.15.254"),
    ("spread-192", "192.0.2.1",    "10.3.0.1", "10.3.15.254"),
]

SPREAD_DPORT_MIN = 8000
SPREAD_DPORT_MAX = 8255

SPREAD_STREAM_PPS = 25_000_000

def _payload(pktsize, l4_hdr_len):
    """Zero payload sized so the assembled frame matches pktsize."""
    return b"\x00" * max(0, pktsize - 14 - 20 - l4_hdr_len)

def _spread_vm(src_min, src_max, l4_pkt_offset_dport=None):
    """FlowVar list shared by every spread profile — randomizes src IP and
    optionally a dport."""
    vars_ = [
        STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                     size=4, op="random"),
        STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
    ]
    if l4_pkt_offset_dport is not None:
        vars_ += [
            STLVmFlowVar(name="dport", min_value=SPREAD_DPORT_MIN,
                         max_value=SPREAD_DPORT_MAX, size=2, op="random"),
            STLVmWrFlowVar(fv_name="dport", pkt_offset=l4_pkt_offset_dport),
        ]
    vars_.append(STLVmFixIpv4(offset="IP"))
    return STLScVmRaw(vars_)

def _spread_profile(pktsize, prefix, l4_fn, l4_len,
                    want_dport=False, filter_dst=None, ip_kw=None):
    """One stream per SPREAD_TARGET: random src IP over the target /16 plus a
    fresh L4 layer from l4_fn() (a factory so scapy doesn't share layer state).

      prefix      names the streams ("" = the bare target name).
      l4_len      L4 header length, for _payload sizing.
      want_dport  add the random-dport FlowVar (udp-rand only).
      filter_dst  restrict to a set of dst IPs (fwd-flood).
      ip_kw       extra IP() fields (frag-flood's MF/frag/id).
    """
    streams = []
    for name, dst, src_min, src_max in SPREAD_TARGETS:
        if filter_dst is not None and dst not in filter_dst:
            continue
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IP(src=src_min, dst=dst, **(ip_kw or {}))
               / l4_fn()
               / Raw(_payload(pktsize, l4_len)))
        vm = _spread_vm(src_min, src_max,
                        l4_pkt_offset_dport="UDP.dport" if want_dport else None)
        streams.append(STLStream(
            name=f"{prefix}-{name}" if prefix else name,
            packet=STLPktBuilder(pkt=pkt, vm=vm),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS)))
    return streams

def build_udp_rand(pktsize):
    """Random-src UDP flood — the existing default behaviour.  Each spread
    target gets one stream that randomises src IP + dport."""
    return _spread_profile(
        pktsize, "", lambda: UDP(sport=4096, dport=SPREAD_DPORT_MIN, chksum=0),
        8, want_dport=True)

def build_syn_flood(pktsize):
    """TCP SYN flood — random src IP, fixed dst:80, SYN flag set.  Models
    the canonical volumetric SYN flood."""
    return _spread_profile(
        pktsize, "syn", lambda: TCP(sport=1025, dport=80, flags="S"), 20)

def build_ack_flood(pktsize):
    """TCP ACK flood — random src IP, fixed dst:80, ACK flag set.  Sneaks
    past stateless drop-non-SYN filters; common in volumetric attacks."""
    return _spread_profile(
        pktsize, "ack",
        lambda: TCP(sport=1025, dport=80, flags="A", seq=1, ack=1), 20)

def build_icmp_flood(pktsize):
    """ICMP echo flood — random src IP, ICMP type 8 (echo request)."""
    return _spread_profile(
        pktsize, "icmp", lambda: ICMP(type=8, code=0), 8)

def build_frag_flood(pktsize):
    """IP-fragment flood — first fragment of an oversized UDP datagram.
    Sets MF=1 with frag=0 so the DUT must hold reassembly state.  Uses
    a fixed dport (frags after the first carry no L4 header anyway)."""
    return _spread_profile(
        pktsize, "frag",
        lambda: UDP(sport=1025, dport=SPREAD_DPORT_MIN, chksum=0), 8,
        ip_kw={"flags": "MF", "frag": 0, "id": 0x4242})

def build_fixed_flood_31(pktsize):
    """Random-src UDP flood, balanced across every DUT RX queue.

    One stream per rule-set target; each randomises its source IP across the
    target's /16 so the NIC's l3-src-only RSS spreads it evenly over all queues
    — measured flatter than hand-picked per-queue IPs (CoV 0.1% vs 17%, no idle
    queue), so no per-queue IP computation is needed.  Fixed dport 8000 keeps
    the flood matching the hot UDP rules.  Drives the DUT to its RX ceiling with
    every poll worker active."""
    return _spread_profile(
        pktsize, "ff31",
        lambda: UDP(sport=4096, dport=SPREAD_DPORT_MIN, chksum=0), 8)

def build_fwd_flood_32(pktsize):
    """True forwarding baseline — random-src UDP to the two routed dsts only.

    Destinations 198.51.100.1 and 192.0.2.1 are both routed via VPP's static
    routes (ip route add ... via 10.0.2.2 in setup.vpp).  10.0.2.1 (the DUT's
    own eth-right IP) is intentionally excluded: traffic addressed to the DUT
    itself is locally consumed by VPP (delivered to local0), not forwarded,
    which would distort the forwarding throughput measurement.

    Random src over each /16 balances RSS across all queues (no per-queue IP
    computation needed).  Use with the pass-through (0-rules) scenario to
    measure VPP's forwarding ceiling independent of FastACL.  dport=9000 avoids
    matching hot UDP rules (8000–8255) so it is also usable with rule-loaded
    scenarios."""
    return _spread_profile(
        pktsize, "fwd32", lambda: UDP(sport=4096, dport=9000, chksum=0), 8,
        filter_dst=("198.51.100.1", "192.0.2.1"))

def build_tcp_flows_31(pktsize):
    """Random-src TCP ACK flood, balanced across every DUT RX queue.

    TCP counterpart of fixed-flood-31: one stream per target, random source IP
    over each /16 for even RSS spread, ACK flag set, dport 8128.  Measures the
    classifier's TCP fast path with every worker active."""
    return _spread_profile(
        pktsize, "tcpf31",
        lambda: TCP(sport=1025, dport=8128, flags="A", seq=1, ack=1), 20)

def build_ipv6_flood(pktsize):
    """IPv6 UDP flood — random src in 2001:db8:{1,2,3}::/64.

    Dst cycles through 2001:db8:ff::1 … 2001:db8:ff::128 so that bench
    rules keyed on distinct dst /128 prefixes each receive traffic and the
    TSS O(tuples) property can be verified.

    Byte offsets (from Ethernet frame start):
      ETH(14) + IPv6 version/tc/flow(4) + payload_len(2) + nh(1) + hlim(1)
             + src(16) + dst(16)
      IPv6 dst starts at byte 38; last byte = 53.
      IPv6 src low 32 bits start at byte 34.
    No header checksum fix needed (IPv6 has none).
    """
    from scapy.layers.inet6 import IPv6

    IPV6_DST_MAX = 128

    IPV6_SPREAD_TARGETS = [
        ("ipv6-spread-0", "2001:db8:ff::1", "2001:db8:1::1"),
        ("ipv6-spread-1", "2001:db8:ff::1", "2001:db8:2::1"),
        ("ipv6-spread-2", "2001:db8:ff::1", "2001:db8:3::1"),
    ]
    payload = b"\x00" * max(0, pktsize - 14 - 40 - 8)

    streams = []
    for name, dst, src_base in IPV6_SPREAD_TARGETS:
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IPv6(src=src_base, dst=dst, hlim=64)
               / UDP(sport=4096, dport=SPREAD_DPORT_MIN, chksum=0)
               / Raw(payload))
        vm = STLScVmRaw([
            STLVmFlowVar(name="src_low", min_value=1, max_value=0x0000FFFF,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_low", pkt_offset=34),
            STLVmFlowVar(name="dst_low", min_value=1, max_value=IPV6_DST_MAX,
                         size=1, op="inc"),
            STLVmWrFlowVar(fv_name="dst_low", pkt_offset=53),
            STLVmFlowVar(name="dport", min_value=SPREAD_DPORT_MIN,
                         max_value=SPREAD_DPORT_MAX, size=2, op="random"),
            STLVmWrFlowVar(fv_name="dport", pkt_offset="UDP.dport"),
        ])
        streams.append(STLStream(
            name=name, packet=STLPktBuilder(pkt=pkt, vm=vm),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        ))
    return streams

COLD_DST_MIN = 0x01000000
COLD_DST_MAX = 0x0FFFFFFF

COLD_DST_MIN = 0x01000000
COLD_DST_MAX = 0x0FFFFFFF

def _cold_flow_cap(step=256):
    """dst_max from /tmp/cold-scan-flows: F flows -> the first F cold /24s at the
    given stride, or the whole 1-15.x table if the file is absent/0."""
    try:
        flows = int(open("/tmp/cold-scan-flows").read().strip())
    except Exception:
        flows = 0
    return (min(COLD_DST_MAX, COLD_DST_MIN + flows * step - 1)
            if flows > 0 else COLD_DST_MAX)

def _scan_vm(src_min, src_max, dst_max, step=256):
    """src IP randomised for even RSS spread, dst IP walked over the cold /24
    table (op="inc", step=256 = one /24 per packet — cheap enough for line rate;
    a second per-packet random var collapses TRex to ~14 Mpps)."""
    return STLScVmRaw([
        STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                     size=4, op="random"),
        STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
        STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                     max_value=dst_max, size=4, op="inc", step=step),
        STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
        STLVmFixIpv4(offset="IP"),
    ])

def build_cold_scan(pktsize):
    """Random-src + random-dst UDP flood that scans the whole cold dst/24 rule
    table.  src is randomised per target /16 for even RSS spread across queues;
    dst is randomised across 1.0.0.0-15.255.255.255 so each packet probes a
    different cold-table bucket.  Unlike every fixed-dst profile, this makes the
    rule table the per-packet lookup working set — so as the table grows past a
    CCX's 16 MB L3 slice, the probes spill to DRAM (the cliff we measure).
    dport 9100 avoids the hot UDP rules so the cost is a pure cold-tuple probe.

    The number of DISTINCT destinations (flows) is capped by /tmp/cold-scan-flows
    if present: F flows -> dst randomised over the first F cold /24 subnets, so the
    lookup working set is exactly F entries.  This lets a sweep vary the working
    set at a fixed table size (flow-count -> which cache level serves the probe).
    Absent/0 -> the full 1-15.x range (~983k flows, the whole table)."""
    dst_max = _cold_flow_cap()
    streams = []
    for name, dst, src_min, src_max in SPREAD_TARGETS:
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IP(src=src_min, dst="1.0.0.0")
               / UDP(sport=4096, dport=9100, chksum=0)
               / Raw(_payload(pktsize, 8)))
        vm = _scan_vm(src_min, src_max, dst_max)
        streams.append(STLStream(
            name=f"coldscan-{name}", packet=STLPktBuilder(pkt=pkt, vm=vm),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        ))
    return streams

REFLECTORS = [
    ("ssdp",      1900, 1024),
    ("cldap",      389, 1500),
    ("ntp",        123,  468),
    ("dns",         53, 1024),
    ("memcached", 11211, 1400),
    ("wsdiscov",  3702, 1024),
    ("coap",      5683,  512),
    ("chargen",     19, 1024),
]

COLD_IMIX = [(64, 7), (570, 4), (1518, 1)]

def build_cold_scan_scatter(pktsize):
    """cold-scan with the destinations SPREAD instead of consecutive.

    Identical to build_cold_scan except the stride: dst steps by 2048 (eight
    /24s) rather than 256 (one).  Same packet rate, same flow count, same rules
    hit — only the spatial pattern of the working set changes.

    This is the adversarial case for anything indexed by rule number.  The
    per-rule counters are two u64 vecs indexed that way, so at stride 8 they sit
    8 x 8 = exactly one cache line apart and every match touches its own pair of
    lines.  Measured on hardware, maintaining them then costs more than the
    classifier lookup: 287 -> 453 cyc/pkt at 28,000 flows, and line rate is lost.

    Stride 8 keeps the sweep inside the 1-15.x cold table: 983,040 /24 rules / 8
    = 122,880 reachable flows, past anything the ceiling sweep needs."""
    step = 256 * 8
    dst_max = _cold_flow_cap(step)
    streams = []
    for name, dst, src_min, src_max in SPREAD_TARGETS:
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IP(src=src_min, dst="1.0.0.0")
               / UDP(sport=4096, dport=9100, chksum=0)
               / Raw(_payload(pktsize, 8)))
        vm = _scan_vm(src_min, src_max, dst_max, step=step)
        streams.append(STLStream(
            name=f"coldscatter-{name}", packet=STLPktBuilder(pkt=pkt, vm=vm),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        ))
    return streams

def build_cold_scan_imix(pktsize):
    """cold-scan with MIXED frame sizes instead of uniform 64 B.

    Same destination walk as cold-scan — so the rule table is still the
    per-packet working set — but frames arrive in the 7:4:1 IMIX rather than all
    at 64 B.  pktsize is ignored by design; the mix defines the sizes.

    Real traffic is not uniform, and receive-path optimisations that batch or
    pack buffers tend to be tuned for one frame size: a uniform-64 B benchmark is
    their best case and hides the regression a mixed stream would expose.  This
    profile is the one that catches it.

    NB the packet RATE is far lower here (avg 354 B → ~33 Mpps fills 100 G), so
    judge this profile on the share of offered traffic absorbed and on what the
    adapter reports dropping, not on absolute Mpps."""
    dst_max = _cold_flow_cap()
    streams = []
    for name, dst, src_min, src_max in SPREAD_TARGETS:
        for size, weight in COLD_IMIX:
            pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
                   / IP(src=src_min, dst="1.0.0.0")
                   / UDP(sport=4096, dport=9100, chksum=0)
                   / Raw(_payload(size, 8)))
            vm = _scan_vm(src_min, src_max, dst_max)
            streams.append(STLStream(
                name=f"coldimix-{name}-{size}",
                packet=STLPktBuilder(pkt=pkt, vm=vm),
                mode=STLTXCont(pps=SPREAD_STREAM_PPS * weight / 12.0),
            ))
    return streams

def build_ip6_cold_scan(pktsize):
    """IPv6 twin of cold-scan: random src, dst walking F distinct /64 prefixes.

    Rules from load-scenario.py's 1m-rules-drop-ip6 cover
    2001:db8:{i>>16}:{i&0xffff}::/64, so writing a 32-bit counter over those two
    hextets makes each packet probe a different bucket.  Byte offsets from the
    Ethernet frame start:

      ETH(14) + ver/tc/flow(4) + payload_len(2) + nh(1) + hlim(1) = 22
      IPv6 src at 22..37, IPv6 dst at 38..53
      dst hextets 3 and 4 (the /64 selector) are bytes 42..45

    Flow count is capped by /tmp/cold-scan-flows exactly as the IPv4 profile
    does, so the same sweep driver varies the IPv6 working set.  dst uses
    op="inc" for the same reason as IPv4: a second per-packet random var starves
    the generator well below line rate.  IPv6 has no header checksum to fix."""
    from scapy.layers.inet6 import IPv6

    try:
        flows = int(open("/tmp/cold-scan-flows").read().strip())
    except Exception:
        flows = 0
    if flows <= 0:
        flows = 983040
    dst_max = flows - 1

    payload = b"\x00" * max(0, pktsize - 14 - 40 - 8)
    streams = []
    for idx, src_base in enumerate(("2001:db8:1::1", "2001:db8:2::1",
                                    "2001:db8:3::1")):
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IPv6(src=src_base, dst="2001:db8::", hlim=64)
               / UDP(sport=4096, dport=9100, chksum=0)
               / Raw(payload))
        vm = STLScVmRaw([
            STLVmFlowVar(name="src_low", min_value=1, max_value=0xFFFFFFFF,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_low", pkt_offset=34),
            STLVmFlowVar(name="dst_idx", min_value=0, max_value=dst_max,
                         size=4, op="inc", step=1),
            STLVmWrFlowVar(fv_name="dst_idx", pkt_offset=42),
        ])
        streams.append(STLStream(
            name=f"ip6-coldscan-{idx}", packet=STLPktBuilder(pkt=pkt, vm=vm),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        ))
    return streams

REFLECTORS = [
    ("ssdp",      1900, 1024),
    ("cldap",      389, 1500),
    ("ntp",        123,  468),
    ("dns",         53, 1024),
    ("memcached", 11211, 1400),
    ("wsdiscov",  3702, 1024),
    ("coap",      5683,  512),
    ("chargen",     19, 1024),
]

COLD_IMIX = [(64, 7), (570, 4), (1518, 1)]

def build_reflection_mix(pktsize):
    """Simultaneous UDP reflection vectors, spread across the protected range.

    pktsize is ignored: each vector carries the frame size its real reflector
    produces, so this is inherently a mixed-size profile."""
    streams = []
    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    share = SPREAD_STREAM_PPS * len(SPREAD_TARGETS) / float(len(REFLECTORS))
    for rname, sport, size in REFLECTORS:
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IP(src=src_min, dst="1.0.0.0")
               / UDP(sport=sport, dport=53, chksum=0)
               / Raw(_payload(size, 8)))
        vm = STLScVmRaw([
            STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
            STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                         max_value=COLD_DST_MAX, size=4, op="inc", step=256),
            STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
            STLVmFixIpv4(offset="IP"),
        ])
        streams.append(STLStream(name=f"refl-{rname}",
                                 packet=STLPktBuilder(pkt=pkt, vm=vm),
                                 mode=STLTXCont(pps=share)))
    return streams

def build_multivector(pktsize):
    """Five attack vectors at once — the shape ~30-38% of real incidents take.

    Carpet-bomb destination scan (64 B) + TCP SYN flood + ICMP flood + IP
    fragments + the UDP reflection mix, sharing one 100 G link.  This is the
    only profile here that stresses all three axes the rest measure separately:
    many destinations (working set), several mask shapes (TSS is O(T)), and a
    wide frame-size distribution (the case uniform-frame benchmarks miss).

    Deliberately built to be hard.  If the box holds line rate here it holds it
    on anything the reports describe."""
    LINE_BPS = 100e9
    WIRE_EXTRA = 24
    N_VEC = 5

    def _pps_for(size, vectors=N_VEC):
        return (LINE_BPS / vectors) / ((size + WIRE_EXTRA) * 8.0)

    streams = []

    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    base = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0")

    streams.append(STLStream(
        name="mv-carpet",
        packet=STLPktBuilder(pkt=base / UDP(sport=4096, dport=9100, chksum=0)
                             / Raw(_payload(64, 8)),
                             vm=_scan_vm(src_min, src_max, COLD_DST_MAX)),
        mode=STLTXCont(pps=_pps_for(64))))
    streams.append(STLStream(
        name="mv-syn",
        packet=STLPktBuilder(pkt=base / TCP(sport=1024, dport=80, flags="S")
                             / Raw(_payload(64, 20)),
                             vm=_scan_vm(src_min, src_max, COLD_DST_MAX)),
        mode=STLTXCont(pps=_pps_for(64))))
    streams.append(STLStream(
        name="mv-icmp",
        packet=STLPktBuilder(pkt=base / ICMP() / Raw(_payload(64, 8)),
                             vm=_scan_vm(src_min, src_max, COLD_DST_MAX)),
        mode=STLTXCont(pps=_pps_for(64))))
    frag = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0",
                                                   frag=8, proto=17)
    streams.append(STLStream(
        name="mv-frag",
        packet=STLPktBuilder(pkt=frag / Raw(_payload(256, 0)),
                             vm=_scan_vm(src_min, src_max, COLD_DST_MAX)),
        mode=STLTXCont(pps=_pps_for(256))))
    for rname, sport, size in REFLECTORS[:4]:
        streams.append(STLStream(
            name=f"mv-refl-{rname}",
            packet=STLPktBuilder(
                pkt=base / UDP(sport=sport, dport=53, chksum=0)
                / Raw(_payload(size, 8)),
                vm=_scan_vm(src_min, src_max, COLD_DST_MAX)),
            mode=STLTXCont(pps=_pps_for(size, N_VEC * 4))))

    try:
        want = {v for v in open("/tmp/mv-vectors").read().strip().split(",") if v}
    except Exception:
        want = set()
    if want:
        streams = [st for st in streams if st.name.split("-")[1] in want]
    return streams

def build_mix_sizes(pktsize):
    """One protocol, MANY frame sizes — isolates size mixing.

    Paired with mix-protos to answer what in multivector defeats the adapter:
    varying packet SIZE, or varying protocol.  All UDP, same ports, same
    destination walk; only the frame length changes between streams."""
    streams = []
    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    sizes = [64, 256, 512, 1024, 1500]
    for size in sizes:
        pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
               / IP(src=src_min, dst="1.0.0.0")
               / UDP(sport=4096, dport=9100, chksum=0)
               / Raw(_payload(size, 8)))
        vm = STLScVmRaw([
            STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
            STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                         max_value=COLD_DST_MAX, size=4, op="inc", step=256),
            STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
            STLVmFixIpv4(offset="IP"),
        ])
        streams.append(STLStream(name=f"mixsz-{size}",
                                 packet=STLPktBuilder(pkt=pkt, vm=vm),
                                 mode=STLTXCont(pps=SPREAD_STREAM_PPS)))
    return streams

def build_mix_protos(pktsize):
    """Many protocols, ONE frame size — isolates protocol mixing.

    The twin of mix-sizes.  Every stream is 64 B; only the L4 protocol differs
    (UDP, TCP, ICMP, and a non-first fragment, which carries no L4 at all).
    NVIDIA documents CQE compression format 4 as being for 'mixed TCP/UDP and
    IPv4/IPv6 traffic', which implies the default format compresses such a mix
    poorly -- this profile is what tests that claim directly.

    /tmp/mix-protos-n (1..4, default 4) truncates the protocol list, which turns
    this into a controlled sweep of the ONE variable that matters: how many
    distinct L4 protocols are interleaved.  Frame size, flow VM and destination
    spread are identical at every N, and TRex renormalises the profile to line
    rate regardless of stream count, so offered pps stays ~142 Mpps throughout.
    That isolates protocol count from every other property of the traffic."""
    try:
        nproto = min(4, max(1, int(open("/tmp/mix-protos-n").read().strip())))
    except Exception:
        nproto = 4
    streams = []
    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    base = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0")

    def _vm():
        return STLScVmRaw([
            STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
            STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                         max_value=COLD_DST_MAX, size=4, op="inc", step=256),
            STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
            STLVmFixIpv4(offset="IP"),
        ])

    for nm, l4 in (("udp", UDP(sport=4096, dport=9100, chksum=0)),
                   ("tcp", TCP(sport=1024, dport=80, flags="S")),
                   ("icmp", ICMP()))[:nproto]:
        hdr = 8 if nm == "udp" else (20 if nm == "tcp" else 8)
        streams.append(STLStream(
            name=f"mixpr-{nm}",
            packet=STLPktBuilder(pkt=base / l4 / Raw(_payload(64, hdr)), vm=_vm()),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS)))
    if nproto >= 4:
        frag = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0",
                                                       frag=8, proto=17)
        streams.append(STLStream(
            name="mixpr-frag",
            packet=STLPktBuilder(pkt=frag / Raw(_payload(64, 0)), vm=_vm()),
            mode=STLTXCont(pps=SPREAD_STREAM_PPS)))
    return streams

def build_mix_udptcp(pktsize):
    """Just UDP + TCP at one size — the minimal protocol mix.

    Sharpens what mix-protos shows: is it protocol mixing in general, or the
    odd members (ICMP, and fragments that carry no L4 header at all)?"""
    streams = []
    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    base = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0")

    def _vm():
        return STLScVmRaw([
            STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
            STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                         max_value=COLD_DST_MAX, size=4, op="inc", step=256),
            STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
            STLVmFixIpv4(offset="IP"),
        ])

    streams.append(STLStream(name="ut-udp", mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        packet=STLPktBuilder(pkt=base / UDP(sport=4096, dport=9100, chksum=0)
                             / Raw(_payload(64, 8)), vm=_vm())))
    streams.append(STLStream(name="ut-tcp", mode=STLTXCont(pps=SPREAD_STREAM_PPS),
        packet=STLPktBuilder(pkt=base / TCP(sport=1024, dport=80, flags="S")
                             / Raw(_payload(64, 20)), vm=_vm())))
    return streams

def build_mix_burst(pktsize):
    """UDP and TCP alternating in BURSTS, not packet-by-packet.

    Every other mixed profile here round-robins the streams, so consecutive
    packets almost always differ in protocol -- the worst possible input for a
    mechanism that compresses runs of similar completions.  Real multi-vector
    traffic is interleaved but probably not perfectly alternating, so this asks
    how much burstiness it takes before CQE compression starts working again.

    Burst length comes from /tmp/mix-burst-size (default 1, i.e. equivalent to
    the round-robin case).  Streams are chained: the UDP burst triggers the TCP
    burst, which triggers the UDP burst again, forever.

    Each stream is given a pps far above line rate on purpose.  Only one stream
    transmits at a time in a chain, so a per-stream rate that looks generous
    still under-offers the port -- the first version of this asked for
    2x SPREAD_STREAM_PPS and quietly delivered 19 Mpps, well under the threshold
    the test exists to probe, and every burst length came back clean."""
    try:
        n = max(1, int(open("/tmp/mix-burst-size").read().strip()))
    except Exception:
        n = 1
    name, dst, src_min, src_max = SPREAD_TARGETS[0]
    base = Ether(src=SENDER_MAC, dst=DUT_MAC) / IP(src=src_min, dst="1.0.0.0")

    def _vm():
        return STLScVmRaw([
            STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                         size=4, op="random"),
            STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
            STLVmFlowVar(name="dst_ip", min_value=COLD_DST_MIN,
                         max_value=COLD_DST_MAX, size=4, op="inc", step=256),
            STLVmWrFlowVar(fv_name="dst_ip", pkt_offset="IP.dst"),
            STLVmFixIpv4(offset="IP"),
        ])

    udp = STLStream(
        name="burst-udp", self_start=True, next="burst-tcp",
        packet=STLPktBuilder(pkt=base / UDP(sport=4096, dport=9100, chksum=0)
                             / Raw(_payload(64, 8)), vm=_vm()),
        action_count=0,
        mode=STLTXSingleBurst(total_pkts=n, pps=200_000_000))
    tcp = STLStream(
        name="burst-tcp", self_start=False, next="burst-udp",
        packet=STLPktBuilder(pkt=base / TCP(sport=1024, dport=80, flags="S")
                             / Raw(_payload(64, 20)), vm=_vm()),
        action_count=0,
        mode=STLTXSingleBurst(total_pkts=n, pps=200_000_000))
    return [udp, tcp]

BNG_SUB_BASE = 0x64400000
BNG_DST      = "198.51.100.10"
BNG_SPORT    = 1024


def _bng_param(path, default):
    try:
        return max(1, int(open(path).read().strip()))
    except (OSError, ValueError):
        return default


def _bng_vm(src_min, src_max, ports):
    ops = []
    if src_max > src_min:
        ops += [STLVmFlowVar(name="sub", min_value=src_min, max_value=src_max, size=4, op="random"),
                STLVmWrFlowVar(fv_name="sub", pkt_offset="IP.src")]
    if ports > 1:
        ops += [STLVmFlowVar(name="sport", min_value=BNG_SPORT, max_value=BNG_SPORT + ports - 1,
                             size=2, op="inc"),
                STLVmWrFlowVar(fv_name="sport", pkt_offset="UDP.sport")]
    return STLScVmRaw(ops + [STLVmFixIpv4(offset="IP")])


def _bng_streams(sizes):
    subs = _bng_param("/tmp/bng-subs", 10000)
    ports = _bng_param("/tmp/bng-ports", 1)
    parts = min(3, subs)
    streams = []
    for i in range(parts):
        lo = BNG_SUB_BASE + i * subs // parts
        hi = BNG_SUB_BASE + (i + 1) * subs // parts - 1
        for size, weight in sizes:
            pkt = (Ether(src=SENDER_MAC, dst=DUT_MAC)
                   / IP(src=socket.inet_ntoa(struct.pack("!I", lo)), dst=BNG_DST)
                   / UDP(sport=BNG_SPORT, dport=443, chksum=0)
                   / Raw(_payload(size, 8)))
            streams.append(STLStream(
                name=f"bng-{i}-{size}", packet=STLPktBuilder(pkt=pkt, vm=_bng_vm(lo, hi, ports)),
                mode=STLTXCont(pps=SPREAD_STREAM_PPS * weight)))
    return streams


def build_bng(pktsize):
    """Subscriber traffic for a BNG pipeline: UDP from subscriber addresses in
    100.64.0.0/10 to one Internet address.  /tmp/bng-subs sets the number of
    subscribers (random source address per packet) and /tmp/bng-ports the source
    ports per subscriber (incremented), so a NAT sees subscribers x ports
    sessions.  With one port, every subscriber is a single flow."""
    return _bng_streams([(pktsize, 1.0)])


def build_bng_imix(pktsize):
    """build_bng with the 7:4:1 IMIX frame mix instead of one size."""
    return _bng_streams([(size, weight / 12.0) for size, weight in COLD_IMIX])


PROFILES = {
    "udp-rand":       build_udp_rand,
    "syn-flood":      build_syn_flood,
    "ack-flood":      build_ack_flood,
    "icmp-flood":     build_icmp_flood,
    "frag-flood":     build_frag_flood,
    "fixed-flood-31": build_fixed_flood_31,
    "fwd-flood-32":   build_fwd_flood_32,
    "tcp-flows-31":   build_tcp_flows_31,
    "cold-scan":      build_cold_scan,
    "cold-scan-scatter": build_cold_scan_scatter,
    "cold-scan-imix": build_cold_scan_imix,
    "bng":            build_bng,
    "bng-imix":       build_bng_imix,
    "ipv6-flood":     build_ipv6_flood,
    "ip6-cold-scan":  build_ip6_cold_scan,
    "reflection-mix": build_reflection_mix,
    "multivector":    build_multivector,
    "mix-sizes":      build_mix_sizes,
    "mix-protos":     build_mix_protos,
    "mix-udptcp":     build_mix_udptcp,
    "mix-burst":      build_mix_burst,
}
