#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

DO_RESET=1
# BlueField target mode.  "nic" = SEPARATED_HOST, the host owns both ports and
# the rig behaves exactly like server1's ConnectX.  "dpu" = EMBEDDED_CPU, the
# DPU Arm owns the uplinks (what the on-DPU bench needs).  Ignored on adapters
# that have no INTERNAL_CPU_MODEL.  Default comes from vars.sh.
BF_MODE="${DUT_BF_MODE:-nic}"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-reset) DO_RESET=0; shift ;;
    --bf-mode)  BF_MODE="$2"; shift 2 ;;
    *) echo "usage: $0 [--no-reset] [--bf-mode nic|dpu]" >&2; exit 2 ;;
  esac
done
case "$BF_MODE" in
  nic|dpu) ;;
  *) echo "mellanox-init: --bf-mode must be 'nic' or 'dpu' (got '$BF_MODE')" >&2; exit 2 ;;
esac
NEED_COLD_CYCLE=0

PCI="${DUT_PCI_LEFT%% *}"

MLXCONFIG=$(command -v mlxconfig || true)
MLXFWRESET=$(command -v mlxfwreset || true)
if [ -z "$MLXCONFIG" ]; then
  echo "mellanox-init: mlxconfig not found — install MFT (setup/setup-host.sh dut). Skipping." >&2
  exit 0
fi

declare -A WANT=(
  [SRIOV_EN]="False(0)"
  [NUM_OF_VFS]="0"
  [LINK_TYPE_P1]="ETH(2)"
  [LINK_TYPE_P2]="ETH(2)"
  [CQE_COMPRESSION]="AGGRESSIVE(1)"
)

echo "mellanox-init: verifying NV config on $PCI ..."
query=$("$MLXCONFIG" -d "$PCI" query 2>/dev/null || true)

# BlueField only.  EMBEDDED_CPU hands the uplinks to the DPU Arm; SEPARATED_HOST
# gives the host direct ownership so the rig behaves like server1's ConnectX.
# NOTE: unlike every other key here this one is NOT activated by mlxfwreset --
# the box needs a cold power cycle (setup/ipmi.sh) before it takes effect.
if grep -q "INTERNAL_CPU_MODEL" <<<"$query"; then
  if [ "$BF_MODE" = "nic" ]; then
    WANT[INTERNAL_CPU_MODEL]="SEPARATED_HOST(0)"
  else
    WANT[INTERNAL_CPU_MODEL]="EMBEDDED_CPU(1)"
  fi
  echo "  BlueField detected — target mode: $BF_MODE (${WANT[INTERNAL_CPU_MODEL]})"
fi

set_args=()
for key in "${!WANT[@]}"; do
  cur=$(echo "$query" | awk -v k="$key" '$1==k{print $2}')
  if [ "$cur" = "${WANT[$key]}" ]; then
    echo "  $key = $cur (ok)"
  else
    echo "  $key = ${cur:-?} -> need ${WANT[$key]}"
    case "$key" in
      SRIOV_EN)        set_args+=("SRIOV_EN=0") ;;
      NUM_OF_VFS)      set_args+=("NUM_OF_VFS=0") ;;
      LINK_TYPE_P1)    set_args+=("LINK_TYPE_P1=2") ;;
      LINK_TYPE_P2)    set_args+=("LINK_TYPE_P2=2") ;;
      CQE_COMPRESSION) set_args+=("CQE_COMPRESSION=1") ;;
      INTERNAL_CPU_MODEL)
        [ "$BF_MODE" = "nic" ] && set_args+=("INTERNAL_CPU_MODEL=0") \
                               || set_args+=("INTERNAL_CPU_MODEL=1")
        NEED_COLD_CYCLE=1 ;;
    esac
  fi
done

if [ "${#set_args[@]}" -gt 0 ]; then
  echo "mellanox-init: applying NV changes: ${set_args[*]}"
  "$MLXCONFIG" -y -d "$PCI" set "${set_args[@]}"
fi

if [ "$NEED_COLD_CYCLE" = "1" ]; then
  echo "mellanox-init: INTERNAL_CPU_MODEL changed -> COLD POWER CYCLE REQUIRED."
  echo "  mlxfwreset does NOT activate this key.  Run:"
  echo "    DUT=$DUT labs/hw/setup/ipmi.sh --target dut cycle   (alice/bob: JetKVM, needs the ATX extension)"
  echo "  then re-run this script to confirm the mode took effect."
fi

MLXLINK=$(command -v mlxlink || true)

# A firmware/NV change (notably an INTERNAL_CPU_MODEL switch) brings the PFs
# back admin-DOWN, and an admin-down PF carries no traffic however healthy the
# physical link is.  Assert them up rather than assuming the host left them so.
_dut_ifaces_up() {
  local i
  for i in "$DUT_IFACE_0" "$DUT_IFACE_1"; do
    [ -n "$i" ] && [ -e "/sys/class/net/$i" ] || continue
    [ "$(cat "/sys/class/net/$i/operstate" 2>/dev/null)" = "up" ] && continue
    echo "  bringing $i up (was $(cat "/sys/class/net/$i/operstate" 2>/dev/null))"
    ip link set "$i" up 2>/dev/null || true
  done
}

_dut_link_up() {
  _dut_ifaces_up
  [ -n "$MLXLINK" ] || return 0
  command -v mst >/dev/null 2>&1 && mst start >/dev/null 2>&1 || true
  local dev
  for dev in "${DUT_PCI_LEFT%% *}" "${DUT_PCI_RIGHT%% *}"; do
    "$MLXLINK" -d "$dev" 2>/dev/null | grep -q "LinkUp" || return 1
  done
  return 0
}

_wait_dut_link_up() {
  local secs="${1:-15}" i=0
  while [ "$i" -lt "$secs" ]; do
    _dut_link_up && return 0
    sleep 2; i=$(( i + 2 ))
  done
  return 1
}

# Nothing to activate and the links are already trained -> skip the reset.  On
# BlueField a level-3 reset restarts the Arm side and can sit for minutes before
# returning "BF reset flow timeout", so resetting a healthy NIC costs real time
# and buys nothing.  A NV change still needs one (or a cold cycle).
if [ "$DO_RESET" = 1 ] && [ "${#set_args[@]}" -eq 0 ] && _wait_dut_link_up 5; then
  echo "mellanox-init: NV config already correct and links trained — skipping firmware reset."
  DO_RESET=0
fi

if [ "$DO_RESET" = 1 ] && [ -n "$MLXFWRESET" ]; then
  tries=$(( 1 + ${DUT_LINK_MAX_FWRESET:-0} ))
  n=1
  while [ "$n" -le "$tries" ]; do
    echo "mellanox-init: firmware reset (mlxfwreset --level 3), attempt $n/$tries ..."
    if ! "$MLXFWRESET" -d "$PCI" -y --level 3 reset; then
      echo "mellanox-init: WARNING mlxfwreset failed — a host reboot/power-cycle may be needed." >&2
      break
    fi
    if _wait_dut_link_up 15; then
      echo "mellanox-init: data link trained (both ports LinkUp)."
      break
    fi
    if [ "$n" -lt "$tries" ]; then
      echo "mellanox-init: link still stuck (Polling) — retrying fw reset ..." >&2
      sleep 3
    else
      echo "mellanox-init: WARNING link not up after $tries reset(s) — check cabling/peer." >&2
    fi
    n=$(( n + 1 ))
  done
elif [ "$DO_RESET" = 1 ]; then
  echo "mellanox-init: mlxfwreset not found — skipping firmware reset." >&2
fi
echo "mellanox-init: done."
