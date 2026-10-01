#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WANT="${1:-}"
case "$WANT" in
  nic) WANT_VAL="SEPARATED_HOST(0)"; WANT_NUM=0 ;;
  dpu) WANT_VAL="EMBEDDED_CPU(1)"; WANT_NUM=1 ;;
  *) echo "usage: bf-mode.sh nic|dpu   (BF_MODE_FORCE=1 cycles even with other users logged in)" >&2
     exit 2 ;;
esac

DUT=epyc
. "$SCRIPT_DIR/vars.sh" >/dev/null 2>&1
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"
ARM="$LAB_SSH_USER@${LAB_HOST_bluefield3:?LAB_HOST_bluefield3 unset}"
HOST="$LAB_SSH_USER@${DUT_HOST:?epyc host unset}"
BF_PCI="${BF_PCI:-03:00.0}"
BOOT_WAIT="${BF_BOOT_WAIT:-1200}"

say() { echo ">> bf-mode: $*"; }

mode_cols() {
  $SSH "$ARM" "sudo -n mlxconfig -d $BF_PCI -e q INTERNAL_CPU_MODEL" 2>/dev/null |
    awk '/INTERNAL_CPU_MODEL/ {print $(NF-1), $NF}'
}

boot_id() { $SSH "$1" "cat /proc/sys/kernel/random/boot_id" 2>/dev/null; }

wait_new_boot() {
  local target="$1" old="$2" name="$3" t=0 id
  while [ "$t" -lt "$BOOT_WAIT" ]; do
    id=$(boot_id "$target")
    [ -n "$id" ] && [ "$id" != "$old" ] && { say "$name is back (${t}s)"; return 0; }
    sleep 15; t=$((t + 15))
  done
  say "$name did not come back within ${BOOT_WAIT}s"; return 1
}

other_users() {
  $SSH "$1" "who | awk '\$1 != \"$LAB_SSH_USER\" {print \$1}' | sort -u | xargs" 2>/dev/null
}

read -r current next <<<"$(mode_cols)"
[ -n "${current:-}" ] || { say "cannot read INTERNAL_CPU_MODEL on the BlueField-3 Arm"; exit 1; }
say "current=$current next-boot=$next want=$WANT_VAL"
[ "$current" = "$WANT_VAL" ] && { say "already in $WANT mode"; exit 0; }

if [ "${BF_MODE_FORCE:-0}" != 1 ]; then
  for t in "$HOST" "$ARM"; do
    u=$(other_users "$t")
    [ -z "$u" ] || { say "refusing to power-cycle: ${t#*@} has users logged in: $u"; exit 1; }
  done
fi

if [ "$next" != "$WANT_VAL" ]; then
  say "setting INTERNAL_CPU_MODEL=$WANT_NUM"
  $SSH "$ARM" "sudo -n mlxconfig -d $BF_PCI -y s INTERNAL_CPU_MODEL=$WANT_NUM" >/dev/null 2>&1 ||
    { say "mlxconfig set failed"; exit 1; }
fi

host_boot=$(boot_id "$HOST"); arm_boot=$(boot_id "$ARM")
say "cold power cycle of ${DUT_HOST%%.*} to apply the mode"
$SSH "$HOST" "sg docker -c 'docker ps -q | xargs -r docker stop -t 10'; sudo -n sync" >/dev/null 2>&1 || true
$SSH "$ARM" "docker ps -q | xargs -r docker stop -t 10; sudo -n sync" >/dev/null 2>&1 || true
DUT=epyc bash "$SCRIPT_DIR/setup/ipmi.sh" cycle || exit 1
wait_new_boot "$HOST" "$host_boot" "${DUT_HOST%%.*}" || exit 1
wait_new_boot "$ARM" "$arm_boot" "BlueField-3 Arm" || exit 1

read -r current next <<<"$(mode_cols)"
[ "${current:-}" = "$WANT_VAL" ] || { say "mode is still ${current:-unknown} after the cycle"; exit 1; }
if [ "$WANT" = dpu ]; then
  for _ in $(seq 1 20); do
    [ "$($SSH "$ARM" "ip -br link | grep -cE '^p[01] '" 2>/dev/null)" = 2 ] && break
    sleep 6
  done
fi
say "BlueField-3 is in $WANT mode"
