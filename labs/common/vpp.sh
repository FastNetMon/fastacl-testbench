#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

vpp_ensure_hugepages() {
  local hp_file="/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"
  local current_hp
  current_hp=$(cat "$hp_file" 2>/dev/null || echo 0)
  if [ "$current_hp" -lt "$HUGEPAGES_NR" ]; then
    echo "Allocating $HUGEPAGES_NR x 1GB hugepages (currently $current_hp)..."
    echo "$HUGEPAGES_NR" > "$hp_file"
    current_hp=$(cat "$hp_file")
    if [ "$current_hp" -lt "$HUGEPAGES_NR" ]; then
      echo "WARNING: Only got $current_hp of $HUGEPAGES_NR hugepages (fragmented memory?)."
      echo "  For reliable allocation, set hugepages on the kernel command line (see fastacl-testbench labs/hw/setup/install.sh), then reboot"
      [ "$current_hp" -eq 0 ] && { echo "ERROR: 0 hugepages — VPP cannot start."; exit 1; }
    else
      echo "  Allocated $current_hp x 1GB hugepages."
    fi
  else
    echo "  Hugepages: $current_hp x 1GB (OK)"
  fi
  if ! mount | grep -q "hugetlbfs"; then
    mkdir -p /dev/hugepages
    mount -t hugetlbfs nodev /dev/hugepages 2>/dev/null || true
  fi
}

vpp_ensure_hugepages_2m() {
  local need="$1"
  local hp_file="/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"
  [ -f "$hp_file" ] || { echo "  (no 2 MB hugepage control file — skipping)"; return 0; }
  local current
  current=$(cat "$hp_file" 2>/dev/null || echo 0)
  if [ "$current" -lt "$need" ]; then
    echo "Pre-allocating ${need} x 2 MB hugepages (currently ${current})..."
    echo "$need" > "$hp_file" 2>/dev/null || true
    current=$(cat "$hp_file")
    if [ "$current" -lt "$need" ]; then
      echo "  WARNING: only got ${current} of ${need} x 2 MB hugepages (fragmented RAM?)."
    else
      echo "  Allocated ${current} x 2 MB hugepages."
    fi
  else
    echo "  2 MB hugepages: ${current} (OK)"
  fi
}

vpp_ensure_cqe_aggressive() {
  command -v mlxconfig >/dev/null 2>&1 || { echo "  (mlxconfig not present — skipping CQE check)"; return 0; }
  local pci cur
  for pci in "$@"; do
    cur=$(mlxconfig -d "$pci" query 2>/dev/null | awk '/CQE_COMPRESSION/{print $2}')
    if echo "$cur" | grep -qi AGGRESSIVE; then
      echo "  $pci: CQE_COMPRESSION already AGGRESSIVE"
    else
      echo "  $pci: CQE_COMPRESSION=${cur:-unknown} → setting AGGRESSIVE"
      mlxconfig -y -d "$pci" set CQE_COMPRESSION=1 >/dev/null 2>&1 || { echo "    set failed"; continue; }
      if mlxfwreset -d "$pci" -y reset >/dev/null 2>&1; then
        echo "    applied live via mlxfwreset"
      else
        echo "    WARNING: set in NV but live reset failed — reboot the host to apply"
      fi
    fi
  done
}

vpp_pre_start() {
  rm -f "$@"
  mkdir -p /run/vpp
  pkill -9 vpp 2>/dev/null || true
  sleep 0.5
}

vpp_kill_graceful() {
  pkill -TERM vpp 2>/dev/null || true
  for i in $(seq 1 20); do pgrep vpp >/dev/null 2>&1 || break; sleep 0.2; done
  if pgrep vpp >/dev/null 2>&1; then
    echo "Force killing VPP..."
    pkill -9 vpp 2>/dev/null || true
    sleep 0.5
  fi
  rm -f "$@"
}
