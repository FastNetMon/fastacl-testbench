#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Write reports/README.md: the static description followed by an index of every report."""

import json
import os
import sys


def rig_record(path):
    try:
        with open(path) as f:
            for line in f:
                row = json.loads(line)
                if row.get("bench") == "rig":
                    return row
    except (OSError, ValueError):
        pass
    return {}


def dut_software(rig):
    sw = rig.get("dut_os", "")
    if sw.startswith("bf-bundle-"):
        parts = sw.split("_")
        return f"DOCA {parts[1]}" if len(parts) > 1 else sw
    if sw:
        return ", ".join(p.strip() for p in sw.split(",") if not p.strip().startswith("bf-release"))
    return f"kernel {rig['dut_kernel']}" if rig.get("dut_kernel") else ""


def verdict_line(path):
    try:
        with open(path) as f:
            for line in f:
                if line.startswith("**"):
                    return line.strip().replace("**", "")
    except OSError:
        pass
    return ""


def main():
    reports = sys.argv[1]
    header = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports-readme.md")
    lines = [open(header).read().rstrip("\n"), "",
             "| Report | Rig | Suite | FastACL | VPP | DUT software | Result |",
             "|---|---|---|---|---|---|---|"]
    for name in sorted(os.listdir(reports), reverse=True):
        folder = os.path.join(reports, name)
        if not os.path.isfile(os.path.join(folder, "report.md")):
            continue
        rig = rig_record(os.path.join(folder, "run.jsonl"))
        parts = name.split("_")
        dut = rig.get("dut") or (parts[2] if len(parts) > 3 else "")
        suite = parts[-1]
        lines.append(f"| [{name}]({name}/) | {dut} | {suite} | {rig.get('plugin_version', '')} | "
                     f"{rig.get('vpp_version', '')} | {dut_software(rig)} | "
                     f"{verdict_line(os.path.join(folder, 'report.md'))} |")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
