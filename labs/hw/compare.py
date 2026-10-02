#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Compare two bench runs measurement by measurement.

Usage: compare.py <run A> <run B> [--out compare.md]
A run is a report folder (containing run.jsonl) or a run.jsonl file. Rows are matched on
bench, sweep, scenario, attack, frame, flows and rule count; the output is a markdown page
with the two rigs' software versions and, per matched measurement, both rates, the wire
Gbps where the frame size is known, cycles per packet and the change from A to B.
"""

import argparse
import json
import os

IMIX_AVG_FRAME = (64 * 7 + 570 * 4 + 1518 * 1) / 12
KEY = ("bench", "sweep", "scenario", "attack", "frame", "flows", "nrules")
VERSIONS = (("dut", "rig"), ("dut_cpu", "DUT CPU"), ("dut_os", "DUT software"),
            ("dut_kernel", "DUT kernel"), ("dut_driver", "NIC driver"), ("vpp_version", "VPP"),
            ("plugin_version", "FastACL"),
            ("vpp_workers", "workers"))


def load(path):
    if os.path.isdir(path):
        path = os.path.join(path, "run.jsonl")
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def key(row):
    return tuple("" if row.get(k) is None else str(row.get(k)) for k in KEY)


def frame_bytes(row):
    frame = row.get("frame")
    if frame in (None, ""):
        return 64 if row.get("bench") in ("oneport", "flows", "survey") else None
    if str(frame).lower() == "imix":
        return IMIX_AVG_FRAME
    try:
        return float(str(frame).split()[0])
    except ValueError:
        return None


def gbps(mpps, frame):
    if mpps is None or frame is None:
        return None
    return mpps * (frame + 24) * 8 / 1000


def num(v):
    return v if isinstance(v, (int, float)) else None


def cell(v, digits=1):
    return "" if v is None else f"{v:.{digits}f}"


def delta(a, b):
    if a is None or b is None or not a:
        return ""
    return f"{(b - a) / a * 100:+.1f}%"


def rate(row):
    m, lo, hi = num(row.get("dut_mpps")), num(row.get("mpps_min")), num(row.get("mpps_max"))
    if m is None:
        return ""
    if lo is not None and hi is not None and (lo, hi) != (m, m):
        return f"{m:.1f} ({lo:.1f}–{hi:.1f})"
    return f"{m:.1f}"


def label(row):
    parts = [row.get("bench", "")]
    for k in ("sweep", "scenario", "attack"):
        if row.get(k):
            parts.append(str(row[k]))
    if row.get("frame") not in (None, ""):
        f = row["frame"]
        parts.append("IMIX" if str(f).lower() == "imix" else f"{float(f):.0f} B" if num(f) else str(f))
    if row.get("flows") not in (None, ""):
        parts.append(f"{int(float(row['flows'])):,} flows")
    if row.get("nrules") not in (None, ""):
        parts.append(f"{int(float(row['nrules'])):,} rules")
    return " · ".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--out")
    args = ap.parse_args()
    a_rows, b_rows = load(args.a), load(args.b)
    a_rig = next((r for r in a_rows if r.get("bench") == "rig"), {})
    b_rig = next((r for r in b_rows if r.get("bench") == "rig"), {})
    b_by_key = {key(r): r for r in b_rows if r.get("bench") not in ("rig", "load")}

    lines = [f"# Bench comparison: {os.path.basename(os.path.normpath(args.a))} vs "
             f"{os.path.basename(os.path.normpath(args.b))}", "",
             "| | A | B |", "|---|---|---|"]
    for k, name in VERSIONS:
        va, vb = (int(v) if isinstance(v, float) and v.is_integer() else v
                  for v in (a_rig.get(k, ""), b_rig.get(k, "")))
        if va or vb:
            lines.append(f"| {name} | {va} | {vb} |")
    lines += ["", "| measurement | A Mpps | B Mpps | change | A Gbps | B Gbps | A cyc/pkt | B cyc/pkt |",
              "|---|---|---|---|---|---|---|---|"]
    matched = 0
    for ra in a_rows:
        if ra.get("bench") in ("rig", "load"):
            continue
        rb = b_by_key.get(key(ra))
        if not rb:
            continue
        ma, mb = num(ra.get("dut_mpps")), num(rb.get("dut_mpps"))
        if ma is None and mb is None:
            continue
        f = frame_bytes(ra)
        lines.append(f"| {label(ra)} | {rate(ra)} | {rate(rb)} | {delta(ma, mb)} | "
                     f"{cell(gbps(ma, f))} | {cell(gbps(mb, f))} | "
                     f"{cell(num(ra.get('cyc_pkt')), 0)} | {cell(num(rb.get('cyc_pkt')), 0)} |")
        matched += 1
    lines += ["", f"{matched} matched measurements. Mpps is the median, with the min–max range of the "
              "trials in brackets where several were taken. Gbps counts frame + 24 B on the wire. "
              "On the BlueField-3 Arm, cycles are 330 MHz generic-timer ticks.", ""]
    text = "\n".join(lines)
    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
    print(text)


if __name__ == "__main__":
    main()
