#!/usr/bin/env python3
"""TRex stateless runner — FastACL hw lab.

Starts traffic streams and shows live stats in a single long-lived process.
Keeping the STLClient connection alive ensures TRex continues traffic until
Ctrl-C.  Streams and rates are defined in traffic.py constants.

Environment variables (with fallback defaults):
  TREX_DIR         — TRex installation directory (default: /opt/trex)
  SENDER_IP        — Source IP for all streams (default: 10.0.1.1)
  SENDER_MAC       — Source MAC address
  DUT_LEFT_MAC     — Destination MAC / DUT ingress MAC
  TREX_RATE        — Traffic rate: "100%" for line rate, or absolute e.g. "100gbps" (default: 100%)
  TREX_PKTSIZE     — Frame size in bytes (default: 64; min 64)
  TREX_STREAM_MODE — Stream mode: 'fixed-dst' or 'random-dst' (default: random-dst)
                     Affects the legacy `udp-rand` profile only — see attacks.py.
  TREX_ATTACK      — Attack profile to load (default: udp-rand)
                     Valid: udp-rand | syn-flood | ack-flood | icmp-flood
                            | frag-flood | fixed-flood | fixed-flood-31
                            | tcp-flows-31
                     See attacks.py for details.

Usage:
  python3 run.py          # start traffic + live stats
  python3 run.py stop     # stop traffic only (no stats loop)
"""

import os
import sys
import time

SENDER_IP        = os.environ.get("SENDER_IP",        "10.0.1.1")
SENDER_MAC       = os.environ["SENDER_MAC"]
DUT_MAC          = os.environ["DUT_LEFT_MAC"]
TREX_RATE        = os.environ.get("TREX_RATE",        "100%")
TREX_PKTSIZE     = max(64, int(os.environ.get("TREX_PKTSIZE", "64")))
TREX_STREAM_MODE = os.environ.get("TREX_STREAM_MODE", "random-dst")
TREX_ATTACK      = os.environ.get("TREX_ATTACK",      "icmp-flood")

ATTACK_FILE = "/tmp/trex-attack"
TX_PORTS = [int(p) for p in os.environ.get("TREX_PORTS", "0").split(",")]

import _trex_env
from trex.common.trex_exceptions import TRexError
from trex.stl.api import (STLClient, STLStream, STLTXCont, STLPktBuilder,
                          STLVmFlowVar, STLVmWrFlowVar, STLScVmRaw, STLVmFixIpv4)
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP, TCP
from scapy.packet import Raw

PKTSIZE = TREX_PKTSIZE
UDP_PAYLOAD = b"\x00" * max(0, PKTSIZE - 14 - 20 - 8)
TCP_PAYLOAD = b"\x00" * max(0, PKTSIZE - 14 - 20 - 20)

DEMO_STREAM_PPS = 1000

def _udp(dst_ip, sport, dport, name):
    pkt = (
        Ether(src=SENDER_MAC, dst=DUT_MAC)
        / IP(src=SENDER_IP, dst=dst_ip)
        / UDP(sport=sport, dport=dport)
        / Raw(UDP_PAYLOAD)
    )
    return STLStream(name=name, packet=STLPktBuilder(pkt=pkt),
                     mode=STLTXCont(pps=DEMO_STREAM_PPS))

def _tcp(dst_ip, sport, dport, name):
    pkt = (
        Ether(src=SENDER_MAC, dst=DUT_MAC)
        / IP(src=SENDER_IP, dst=dst_ip)
        / TCP(sport=sport, dport=dport)
        / Raw(TCP_PAYLOAD)
    )
    return STLStream(name=name, packet=STLPktBuilder(pkt=pkt),
                     mode=STLTXCont(pps=DEMO_STREAM_PPS))

def _demo_streams():
    """Low-rate demo streams, each targeting a specific FastACL rule."""
    return [
        _udp("10.0.2.2",      1234, 5678, "background"),
        _udp("198.51.100.1",  3333, 4444, "hit-rule1"),
        _udp("10.0.2.2",        53, 7777, "hit-rule3"),
        _udp("192.0.2.1",     1111, 2222, "hit-rule0"),
        _tcp("10.0.2.2",         0,   80, "hit-rule2"),
        _udp("192.0.2.100",   5555, 6666, "hit-priority"),
    ]

SPREAD_DPORT_MIN = 8000
SPREAD_DPORT_MAX = 8255

SPREAD_TARGETS = [
    ("spread-10",  "10.0.2.",      "10.1.0.1", "10.1.15.254"),
    ("spread-198", "198.51.100.",  "10.2.0.1", "10.2.15.254"),
    ("spread-192", "192.0.2.",     "10.3.0.1", "10.3.15.254"),
]

def _spread_vm(src_min, src_max, dport_min, dport_max, random_dst):
    """Build the FlowVar list shared by both spread modes."""
    vars = [
        STLVmFlowVar(name="src_ip", min_value=src_min, max_value=src_max,
                     size=4, op="random"),
        STLVmWrFlowVar(fv_name="src_ip", pkt_offset="IP.src"),
        STLVmFlowVar(name="dport", min_value=dport_min, max_value=dport_max,
                     size=2, op="random"),
        STLVmWrFlowVar(fv_name="dport", pkt_offset="UDP.dport"),
    ]
    if random_dst:
        vars += [
            STLVmFlowVar(name="dst_lsb", min_value=1, max_value=254,
                         size=1, op="random"),
            STLVmWrFlowVar(fv_name="dst_lsb", pkt_offset="IP.dst", offset_fixup=3),
        ]
    vars.append(STLVmFixIpv4(offset="IP"))
    return STLScVmRaw(vars)

SPREAD_STREAM_PPS = 25_000_000

def _udp_spread(name, dst_ip, src_min, src_max,
                dport_min=SPREAD_DPORT_MIN, dport_max=SPREAD_DPORT_MAX,
                random_dst=False):
    """UDP spread stream: random src IP + random dport, optionally random dst LSB."""
    pkt = (
        Ether(src=SENDER_MAC, dst=DUT_MAC)
        / IP(src=src_min, dst=dst_ip)
        / UDP(sport=4096, dport=dport_min, chksum=0)
        / Raw(UDP_PAYLOAD)
    )
    vm = _spread_vm(src_min, src_max, dport_min, dport_max, random_dst)
    return STLStream(name=name, packet=STLPktBuilder(pkt=pkt, vm=vm),
                     mode=STLTXCont(pps=SPREAD_STREAM_PPS))

def _build_streams(mode, attack):
    """6 fixed-tuple demo streams + spread/attack streams selected by mode.

    For attack=='udp-rand' (legacy default) the spread streams use the
    in-file _udp_spread helper which honours TREX_STREAM_MODE.  For every
    other attack the streams come from the attacks.py registry — the
    stream-mode flag is ignored there because those profiles always
    randomise src IP and don't use dst-LSB cycling. """
    common = _demo_streams()

    if attack == "udp-rand":
        if mode not in ("fixed-dst", "random-dst"):
            raise SystemExit(
                f"unknown TREX_STREAM_MODE={mode!r}; expected "
                "'fixed-dst' or 'random-dst'"
            )
        random_dst = (mode == "random-dst")
        spread = [
            _udp_spread(name, dst_pfx + "1", src_min, src_max,
                        random_dst=random_dst)
            for name, dst_pfx, src_min, src_max in SPREAD_TARGETS
        ]
        return common + spread

    from attacks import PROFILES
    if attack not in PROFILES:
        raise SystemExit(
            f"unknown TREX_ATTACK={attack!r}; valid: {', '.join(PROFILES)}"
        )
    return common + PROFILES[attack](TREX_PKTSIZE)

STREAMS = _build_streams(TREX_STREAM_MODE, TREX_ATTACK)

def fmt_bps(b):
    if b >= 1e9:  return f"{b/1e9:6.2f} Gbps"
    if b >= 1e6:  return f"{b/1e6:6.2f} Mbps"
    if b >= 1e3:  return f"{b/1e3:6.2f} Kbps"
    return        f"{b:6.0f}  bps"

def fmt_pps(p):
    if p >= 1e6:  return f"{p/1e6:6.3f} Mpps"
    if p >= 1e3:  return f"{p/1e3:6.2f} Kpps"
    return        f"{p:6.0f}  pps"

def _load_attack(c, attack, rate=None):
    """(Re)build streams for the named attack and start traffic."""
    if attack == "udp-rand":
        streams = _build_streams(TREX_STREAM_MODE, "udp-rand")
    elif attack == "stop":
        c.stop(ports=TX_PORTS)
        return 0
    else:
        import importlib, attacks as _atk
        importlib.reload(_atk)
        PROFILES = _atk.PROFILES
        if attack not in PROFILES:
            print(f"WARN: unknown attack {attack!r}; ignoring", file=sys.stderr)
            return 0
        common = _demo_streams()
        streams = common + PROFILES[attack](PKTSIZE)
    c.reset(ports=TX_PORTS)
    c.add_streams(streams, ports=TX_PORTS)
    c.start(ports=TX_PORTS, mult=(rate or TREX_RATE), force=True)
    return len(streams)

def _reconnect(c):
    """Re-establish the server session and port ownership after an RPC failure."""
    while True:
        try:
            c.disconnect()
        except TRexError:
            pass
        try:
            c.connect()
            c.acquire(ports=TX_PORTS, force=True)
            return
        except TRexError as e:
            print(f"[{time.strftime('%H:%M:%S')}] reconnect failed ({e}); retrying in 5 s")
            time.sleep(5)

def _read_requested_attack():
    """Return (attack, rate) from the hand-off file: "<attack>" or
    "<attack> <rate>", rate being any TRex mult string."""
    try:
        with open(ATTACK_FILE) as f:
            parts = f.read().split()
    except FileNotFoundError:
        return None, None
    if not parts:
        return None, None
    return parts[0], (parts[1] if len(parts) > 1 else None)

def _attack_file_mtime():
    try:
        return os.stat(ATTACK_FILE).st_mtime_ns
    except FileNotFoundError:
        return None

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "start"

    c = STLClient()
    c.connect()

    try:
        c.acquire(ports=TX_PORTS, force=True)

        if action == "stop":
            c.stop(ports=TX_PORTS)
            print(f"TRex traffic stopped on ports {TX_PORTS}.")
            return

        current = TREX_ATTACK
        current_rate = TREX_RATE
        n_streams = _load_attack(c, current, current_rate)
        try:
            with open(ATTACK_FILE, "w") as f:
                f.write(current + "\n")
        except OSError:
            pass
        seen = _attack_file_mtime()

        print(f"TRex traffic started on port 0 at {current_rate} "
              f"({n_streams} streams, attack={current}, "
              f"mode={TREX_STREAM_MODE}, pktsize={PKTSIZE}B).")
        print("Ctrl-C to stop.\n")

        while True:
            wanted, wanted_rate = _read_requested_attack()
            wanted_rate = wanted_rate or TREX_RATE
            mtime = _attack_file_mtime()
            try:
                if wanted and (wanted != current or wanted_rate != current_rate or mtime != seen):
                    seen = mtime
                    print(f"\n[{time.strftime('%H:%M:%S')}] swap {current}@{current_rate}"
                          f" → {wanted}@{wanted_rate}")
                    n_streams = _load_attack(c, wanted, wanted_rate)
                    current, current_rate = wanted, wanted_rate
                    time.sleep(1)
                stats = c.get_stats(ports=[0, 1])
            except TRexError as e:
                print(f"\n[{time.strftime('%H:%M:%S')}] TRex RPC failed ({e}); reconnecting")
                _reconnect(c)
                current = None
                continue
            p0 = stats.get(0, {})
            p1 = stats.get(1, {})

            tx_bps = p0.get("tx_bps",   0.0)
            tx_pps = p0.get("tx_pps",   0.0)
            rx_bps = p1.get("rx_bps",   0.0)
            rx_pps = p1.get("rx_pps",   0.0)
            tx_pkts = p0.get("opackets", 0)
            rx_pkts = p1.get("ipackets", 0)

            sys.stdout.write("\033[2J\033[H")
            sys.stdout.flush()
            ts = time.strftime("%Y-%m-%d %H:%M:%S")
            print(f"=== FastACL hw-lab — TRex Live Stats ===   {ts}  [{PKTSIZE}B frames]")
            print(f"    {SENDER_IP} (port 0 TX)  ──►  DUT [FastACL]  ──►  port 1 RX (sink)")
            print(f"    attack: {current}   streams: {n_streams}   rate: {current_rate}")
            print()
            print(f"  Port 0 TX : {fmt_bps(tx_bps)}   {fmt_pps(tx_pps)}")
            print(f"  Port 1 RX : {fmt_bps(rx_bps)}   {fmt_pps(rx_pps)}")
            print()
            print(f"  Total TX pkts  : {tx_pkts:,}")
            print(f"  Total RX pkts  : {rx_pkts:,}")
            print()
            print(f"  Switch attack: write attack name to {ATTACK_FILE}")
            print("  Ctrl-C to stop traffic and exit")

            time.sleep(2)

    except KeyboardInterrupt:
        print("\nStopping traffic...")
        c.stop(ports=TX_PORTS)
    finally:
        c.disconnect()

if __name__ == "__main__":
    main()
