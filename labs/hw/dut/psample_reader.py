#!/usr/bin/env python3
"""psample_reader.py — read sampled packets off the kernel psample channel.

The consumer side of `fastacl psample enable`.  A rule carrying `sample <N>
group <G>` delivers a 1-in-N copy of every matched packet to the psample
generic-netlink multicast group; this reads them and exposes the metadata each
one carries — sampling rate, group, ingress ifindex, and the packet's original
length before truncation.

Importable:
    from psample_reader import PsampleReader
    r = PsampleReader()                 # resolves family + 'packets' group,
                                        # subscribes before any traffic
    samples = r.collect(expect=10, timeout=5.0)   # list of metadata dicts
    r.close()

Standalone (the lab tool this replaces):
    psample_reader.py [seconds]         # count samples, print first metadata

Stdlib only — no scapy/vpp_papi — so it runs anywhere the psample module is
loaded, including inside the CI container and on the HW DUT.
"""
import errno
import socket
import struct
import sys
import time

NETLINK_GENERIC = 16
GENL_ID_CTRL = 16
CTRL_CMD_GETFAMILY = 3
CTRL_ATTR_FAMILY_ID = 1
CTRL_ATTR_FAMILY_NAME = 2
CTRL_ATTR_MCAST_GROUPS = 7
CTRL_ATTR_MCAST_GRP_NAME = 1
CTRL_ATTR_MCAST_GRP_ID = 2
SOL_NETLINK = 270
NETLINK_ADD_MEMBERSHIP = 1

PSAMPLE_ATTR_IIFINDEX = 0
PSAMPLE_ATTR_ORIGSIZE = 2
PSAMPLE_ATTR_SAMPLE_GROUP = 3
PSAMPLE_ATTR_GROUP_SEQ = 4
PSAMPLE_ATTR_SAMPLE_RATE = 5
PSAMPLE_ATTR_DATA = 6
PSAMPLE_ATTR_PROTO = 14

_SCALAR_ATTRS = {
    PSAMPLE_ATTR_IIFINDEX: "iifindex",
    PSAMPLE_ATTR_ORIGSIZE: "origsize",
    PSAMPLE_ATTR_SAMPLE_GROUP: "group",
    PSAMPLE_ATTR_GROUP_SEQ: "seq",
    PSAMPLE_ATTR_SAMPLE_RATE: "rate",
    PSAMPLE_ATTR_PROTO: "proto",
}

_SCALAR_FMT = {2: "=H", 4: "=I", 8: "=Q"}

def _align(n):
    return (n + 3) & ~3

def _parse_attrs(buf):
    """Yield (type, payload) for a flat netlink attribute block."""
    off = 0
    while off + 4 <= len(buf):
        alen, atype = struct.unpack_from("=HH", buf, off)
        if alen < 4 or off + alen > len(buf):
            break
        yield atype & 0x3FFF, buf[off + 4 : off + alen]
        off += _align(alen)

def resolve():
    """Look up the psample family id and its 'packets' multicast group.

    Returns (family_id, group_id); either is None when the psample module is
    not loaded.
    """
    s = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_GENERIC)
    try:
        name = b"psample\0"
        attr = struct.pack("=HH", 4 + len(name), CTRL_ATTR_FAMILY_NAME) + name
        attr += b"\0" * (_align(len(attr)) - len(attr))
        genl = struct.pack("=BBH", CTRL_CMD_GETFAMILY, 1, 0)
        payload = genl + attr
        nlh = struct.pack("=IHHII", 16 + len(payload), GENL_ID_CTRL, 1, 1, 0)
        s.send(nlh + payload)
        data = s.recv(65536)
    finally:
        s.close()

    if len(data) < 20 or struct.unpack_from("=H", data, 4)[0] == 2:
        return None, None

    body = data[16 + 4 :]
    fam = grp = None
    for atype, val in _parse_attrs(body):
        if atype == CTRL_ATTR_FAMILY_ID:
            fam = struct.unpack_from("=H", val)[0]
        elif atype == CTRL_ATTR_MCAST_GROUPS:
            for _, gnest in _parse_attrs(val):
                gname = gid = None
                for gt, gv in _parse_attrs(gnest):
                    if gt == CTRL_ATTR_MCAST_GRP_NAME:
                        gname = gv.split(b"\0")[0].decode()
                    elif gt == CTRL_ATTR_MCAST_GRP_ID:
                        gid = struct.unpack_from("=I", gv)[0]
                if gname == "packets":
                    grp = gid
    return fam, grp

def parse_sample(buf):
    """Parse one psample netlink message into a metadata dict.

    Keys: rate, group, iifindex, origsize, seq (ints, when present) and bytes
    (payload length actually delivered).  Returns None if the message is too
    short to be a sample.
    """
    if len(buf) < 20:
        return None
    meta = {}
    for atype, val in _parse_attrs(buf[20:]):
        key = _SCALAR_ATTRS.get(atype)
        fmt = _SCALAR_FMT.get(len(val))
        if key is not None and fmt is not None:
            meta[key] = struct.unpack_from(fmt, val)[0]
        elif atype == PSAMPLE_ATTR_DATA:
            meta["bytes"] = len(val)
    return meta

class PsampleReader:
    """Subscribe to the psample 'packets' group and collect samples.

    Construct BEFORE the traffic that produces samples: multicast delivery is
    not buffered for a socket that has not joined yet.
    """

    def __init__(self, rcvbuf=8 << 20):
        self.family, self.group = resolve()
        if not self.family or not self.group:
            raise RuntimeError(
                "psample family not found — is the psample module loaded?")
        self.sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW,
                                  NETLINK_GENERIC)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, rcvbuf)
        self.sock.bind((0, 0))
        self.sock.setsockopt(SOL_NETLINK, NETLINK_ADD_MEMBERSHIP, self.group)
        self.sock.settimeout(0.5)

    def collect(self, expect=None, timeout=5.0):
        """Receive samples until `timeout` elapses, or `expect` are in hand.

        Returns a list of metadata dicts (see parse_sample).
        """
        out = []
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                buf = self.sock.recv(65536)
            except socket.timeout:
                continue
            except OSError as e:
                if e.errno == errno.ENOBUFS:
                    continue
                raise
            meta = parse_sample(buf)
            if meta is not None:
                out.append(meta)
                if expect is not None and len(out) >= expect:
                    break
        return out

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass

def main():
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0
    try:
        r = PsampleReader()
    except RuntimeError as e:
        print(e)
        return 1
    print(f"psample family={r.family} packets-group={r.group}")
    samples = r.collect(timeout=secs)
    r.close()
    print(f"samples received: {len(samples)}")
    if samples:
        f = samples[0]
        print(
            "first sample metadata: "
            f"rate=1:{f.get('rate')} group={f.get('group')} "
            f"iifindex={f.get('iifindex')} origsize={f.get('origsize')} "
            f"payload={f.get('bytes')}B"
        )
    return 0

if __name__ == "__main__":
    sys.exit(main())
