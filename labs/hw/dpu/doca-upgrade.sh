#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail

HW="$(cd "$(dirname "$0")/.." && pwd)"
VER="${1:?usage: doca-upgrade.sh <DOCA version, e.g. 3.4.0>}"
DUT=epyc
. "$HW/vars.sh" >/dev/null 2>&1
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o ServerAliveInterval=15"
ARM="$LAB_SSH_USER@${LAB_HOST_bluefield3:?}"
REPO="https://linux.mellanox.com/public/repo/doca/$VER/ubuntu22.04/dpu-arm64"

say() { echo ">> doca-upgrade: $*"; }

state() {
  $SSH "$ARM" 'echo "bundle=$(cat /etc/mlnx-release) kernel=$(uname -r)" \
    "doca-runtime=$(dpkg-query -W -f="\${Version}" doca-runtime 2>/dev/null)" \
    "nic-fw=$(sudo -n flint -d 03:00.0 q 2>/dev/null | awk -F": *" "/^FW Version/{print \$2}")"'
}

curl -fsI "$REPO/Packages" >/dev/null || { say "no DPU repository for DOCA $VER at $REPO"; exit 1; }
say "before: $(state)"

$SSH "$ARM" "REPO='$REPO' bash -s" <<'REMOTE' || { say "package upgrade failed"; exit 1; }
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a LC_ALL=C
list=/etc/apt/sources.list.d/doca.list
[ -f "$list" ] && sudo cp "$list" "$list.bak.$(date +%Y%m%d%H%M%S)"
curl -fsSL "$REPO/nvidia-doca-debian-gpg-public-key.asc" | gpg --dearmor |
  sudo tee /etc/apt/trusted.gpg.d/nvidia-doca.gpg >/dev/null
echo "deb [signed-by=/etc/apt/trusted.gpg.d/nvidia-doca.gpg] $REPO ./" | sudo tee "$list" >/dev/null
sudo apt-get update -qq
opts=(-y -q -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
sudo -E apt-get install "${opts[@]}" doca-runtime bf-release bf-fwbundle
sudo -E apt-get upgrade "${opts[@]}"
sudo -E /opt/mellanox/mlnx-fw-updater/mlnx_fw_updater.pl
sudo bfrec --capsule
sync
REMOTE

say "packages, NIC firmware and boot image staged; cold power cycle to load them"
"$HW/bf-mode.sh" cycle || exit 1
say "after: $(state)"
