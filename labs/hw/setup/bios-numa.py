#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

"""Set the NUMA options of epyc-sp5's BIOS (Supermicro H13SSL-N, AMI Aptio) through
the BMC's HTML5 KVM, then check the result on the booted host.

    bios-numa.py --nps 4 [--l3-numa auto|enabled|disabled] [--shots DIR]

The KVM drops keys sent less than ~0.8 s apart, hence the pauses.  The BMC has no DCMS licence, so Redfish refuses BIOS settings; this drives the
setup screens instead.  It sets the next boot to BIOS setup (IPMI), reboots the
host, logs into the BMC web UI through a SOCKS tunnel to LAB_PROXY, opens the KVM,
waits for the setup screen and types:
Advanced > ACPI Settings > NUMA Nodes Per Socket / ACPI SRAT L3 Cache As NUMA
Domain, then F4 (save and exit).  After boot it compares `numactl -H` with the
expected node count and exits non-zero on a mismatch.  Screenshots of every step
go to --shots.  Needs playwright with chromium on the machine running it.
"""

import argparse
import os
import shlex
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

HW = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NPS = ["0", "1", "2", "4", "auto"]
L3 = ["disabled", "enabled", "auto"]
SOCKS = 18089


def lab_env():
    env = {}
    out = subprocess.run(["bash", "-c", f"set -a; . {shlex.quote(os.path.join(HW, 'lab.env'))}; env"],
                         capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        k, _, v = line.partition("=")
        env[k] = v
    return env


def ssh(host, cmd, check=True):
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, cmd],
                          capture_output=True, text=True, check=check).stdout


def ipmi(e, args):
    return ssh(e["LAB_PROXY"], f"ipmitool -I lanplus -H {e['LAB_IPMI_HOST_epyc']} -U {e['LAB_IPMI_USER_epyc']} "
                               f"-P {shlex.quote(e['LAB_IPMI_PASS_epyc'])} {args}")


def in_setup(page):
    shot = page.screenshot()
    from io import BytesIO
    from PIL import Image
    im = Image.open(BytesIO(shot)).convert("RGB")
    return im.getpixel((300, 135)) == (0, 0, 152) and im.getpixel((400, 400)) != (0, 0, 0)


def key(page, k):
    page.keyboard.press(k)
    time.sleep(0.8)


def selected(page, x0, y0, n):
    from io import BytesIO
    from PIL import Image
    im = Image.open(BytesIO(page.screenshot())).convert("RGB")
    black = [sum(im.getpixel((x, y0 + 19 * i)) == (0, 0, 0) for x in range(x0, x0 + 30)) for i in range(n)]
    return black.index(max(black))


def pick(page, options, want, x0, y0):
    # The option lists wrap, so move relative to the highlighted (black) row.
    cur = selected(page, x0, y0, len(options))
    for _ in range((options.index(want) - cur) % len(options)):
        key(page, "ArrowDown")
    key(page, "Enter")
    time.sleep(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nps", choices=NPS, required=True)
    ap.add_argument("--l3-numa", choices=L3, default="auto")
    ap.add_argument("--shots", default="/tmp/bios-numa")
    a = ap.parse_args()
    e = lab_env()
    host = f"{e.get('LAB_SSH_USER', os.environ['USER'])}@{e['LAB_HOST_epyc']}"
    os.makedirs(a.shots, exist_ok=True)
    busy = ssh(host, "docker ps -q | wc -l").strip()
    if busy != "0":
        sys.exit(f"bios-numa: {busy} container(s) running on epyc-sp5; stop them first")

    tunnel = subprocess.Popen(["ssh", "-N", "-o", "ExitOnForwardFailure=yes", "-D", str(SOCKS), e["LAB_PROXY"]])
    try:
        time.sleep(3)
        print(ipmi(e, "chassis bootdev bios").strip())
        ssh(host, "sudo systemctl reboot", check=False)
        with sync_playwright() as p:
            b = p.chromium.launch(headless=True, proxy={"server": f"socks5://localhost:{SOCKS}"})
            ctx = b.new_context(ignore_https_errors=True, viewport={"width": 1400, "height": 1000})
            page = ctx.new_page()
            page.goto(f"https://{e['LAB_IPMI_HOST_epyc']}/", timeout=60000)
            page.fill("#usrName", e["LAB_IPMI_USER_epyc"])
            page.fill("#pwd", e["LAB_IPMI_PASS_epyc"])
            page.click("#login_word")
            time.sleep(8)
            page.click("text=Remote Control")
            time.sleep(4)
            with ctx.expect_page(timeout=60000) as kvm_info:
                page.mouse.click(675, 384)
            kvm = kvm_info.value
            deadline = time.time() + 900
            while not in_setup(kvm):
                if time.time() > deadline:
                    kvm.screenshot(path=f"{a.shots}/timeout.png")
                    sys.exit("bios-numa: BIOS setup screen did not appear")
                time.sleep(8)
            time.sleep(5)
            kvm.mouse.click(650, 800)
            for k in ["ArrowRight", "Home"] + ["ArrowDown"] * 4 + ["Enter"]:
                key(kvm, k)
            time.sleep(1)
            kvm.screenshot(path=f"{a.shots}/1-acpi.png")
            for k in ["Home", "ArrowDown", "ArrowDown", "Enter"]:
                key(kvm, k)
            pick(kvm, NPS, a.nps, 538, 381)
            for k in ["ArrowDown", "Enter"]:
                key(kvm, k)
            pick(kvm, L3, a.l3_numa, 490, 399)
            kvm.screenshot(path=f"{a.shots}/2-set.png")
            kvm.keyboard.press("F4")
            time.sleep(1.5)
            kvm.screenshot(path=f"{a.shots}/3-save.png")
            kvm.keyboard.press("Enter")
            time.sleep(2)
            b.close()
    finally:
        tunnel.terminate()

    deadline = time.time() + 900
    while time.time() < deadline:
        if subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", host, "true"],
                          capture_output=True).returncode == 0:
            break
        time.sleep(15)
    nodes = ssh(host, "numactl -H | sed -n 's/^available: \\([0-9]*\\) nodes.*/\\1/p'").strip()
    want = {"enabled": "8"}.get(a.l3_numa) or {"0": "1", "1": "1", "2": "2", "4": "4", "auto": "1"}[a.nps]
    print(f"epyc-sp5: {nodes} NUMA node(s), expected {want}")
    return 0 if nodes == want else 1


if __name__ == "__main__":
    sys.exit(main())
