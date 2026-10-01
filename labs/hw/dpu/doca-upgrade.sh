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
settle() {
  for k in /lib/modules/*/; do sudo depmod -a "$(basename "$k")" 2>/dev/null || true; done
  sudo -E dpkg --configure -a
}
settle
opts=(-y -q -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
sudo -E apt-get install "${opts[@]}" doca-runtime bf-release bf-fwbundle || settle
sudo -E apt-get full-upgrade "${opts[@]}" || settle
settle
kver=$(dpkg-query -W -f='${Depends}' linux-image-bluefield | grep -o 'linux-image-[0-9.-]*-bluefield' | head -1)
kver=${kver#linux-image-}
[ -f "/boot/vmlinuz-$kver" ] && [ -f "/boot/initrd.img-$kver" ] ||
  { echo "kernel $kver or its initramfs missing in /boot" >&2; exit 1; }
modinfo -k "$kver" mlx5_core >/dev/null || { echo "no mlx5_core for kernel $kver" >&2; exit 1; }
echo "boot kernel: $kver, mlx5_core $(modinfo -k "$kver" -F version mlx5_core)"
sudo bfrec --capsule
sync
REMOTE

say "packages and boot image staged; cold power cycle into the new kernel"
"$HW/bf-mode.sh" cycle || exit 1
say "booted: $(state)"

$SSH "$ARM" 'set -e; sudo -n flint -d 03:00.0 q >/dev/null
  sudo -n /opt/mellanox/mlnx-fw-updater/mlnx_fw_updater.pl 2>&1 | grep -vi "locale"; sync' ||
  { say "NIC firmware update failed"; exit 1; }
say "NIC firmware staged; cold power cycle to activate it"
"$HW/bf-mode.sh" cycle || exit 1
say "after: $(state)"
