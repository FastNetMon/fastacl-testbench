#!/usr/bin/env bash
set -euo pipefail

if [ "${FASTACL_SKIP_PERF_TUNE:-0}" = "1" ]; then
  echo "=== FastACL perf-tune: SKIPPED (FASTACL_SKIP_PERF_TUNE=1) ==="
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ROLE="${1:-}"
case "$ROLE" in lava|flame|dell|alice|bob) export GEN="$ROLE" ;; esac
source "$SCRIPT_DIR/../vars.sh"

if [[ ! "$ROLE" =~ ^(lava|flame|dell|alice|bob|dut)$ ]]; then
  echo "Usage: $0 [lava|flame|dell|alice|bob|dut]"
  exit 1
fi

echo "=== FastACL perf-tune ($ROLE) ==="

echo ""
echo "[1/8] CPU governor → performance..."
changed=0
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [ -f "$f" ] || continue
  [ "$(cat "$f" 2>/dev/null)" = "performance" ] && continue
  echo performance > "$f" 2>/dev/null && changed=$((changed + 1)) || true
done
cur=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
[ "$changed" -gt 0 ] && echo "  Set $changed CPUs → $cur" || echo "  Already: $cur"

echo ""
echo "[2/8] C-states above C1 → disabled..."
disabled=0
for dir in /sys/devices/system/cpu/cpu*/cpuidle/state*; do
  name_f="$dir/name"
  dis_f="$dir/disable"
  [ -f "$name_f" ] && [ -f "$dis_f" ] || continue
  name=$(cat "$name_f" 2>/dev/null || echo "")
  case "$name" in POLL|C0|C1|C1E) continue ;; esac
  [ "$(cat "$dis_f" 2>/dev/null)" = "1" ] && continue
  echo 1 > "$dis_f" 2>/dev/null && disabled=$((disabled + 1)) || true
done
command -v cpupower &>/dev/null && cpupower idle-set -D 1 >/dev/null 2>&1 || true
echo "  Disabled $disabled C-state entries (C2+ across all CPUs)."

echo ""
echo "[3/8] PCIe MaxReadRequest → 1024 B..."

_mrr_1024() {
  local pci="$1"
  [ -e "/sys/bus/pci/devices/$pci" ] || { echo "  $pci: not present — skipping"; return 0; }
  if ! command -v setpci &>/dev/null; then
    apt-get install -y -qq pciutils >/dev/null 2>&1 || true
  fi
  command -v setpci &>/dev/null            || { echo "  setpci not found — skipping"; return 0; }
  local cur cur_dec new_val new_hex
  cur=$(setpci -s "$pci" cap_exp+0x8.w 2>/dev/null) || { echo "  $pci: setpci read failed"; return 0; }
  cur_dec=$(printf '%d' "0x${cur}")
  new_val=$(( (cur_dec & 0x8FFF) | 0x3000 ))
  new_hex=$(printf '%04x' $new_val)
  if [ "$cur" = "$new_hex" ]; then
    echo "  $pci: already 1024 B (DevCtrl=0x${cur})"
  else
    setpci -s "$pci" cap_exp+0x8.w="$new_hex"
    echo "  $pci: DevCtrl 0x${cur} → 0x${new_hex}  (MRR 1024 B)"
  fi
}

case "$ROLE" in
  lava|flame|dell|alice|bob) _mrr_1024 "$SENDER_PCI";  _mrr_1024 "$RECEIVER_PCI"  ;;
  dut)   _mrr_1024 "$DUT_PCI_LEFT"; _mrr_1024 "$DUT_PCI_RIGHT" ;;
esac

echo ""
echo "[4/8] NIC flow control → off..."

_fc_off() {
  local iface="$1"
  ip link show "$iface" &>/dev/null 2>&1 || { echo "  $iface: not found — skipping"; return 0; }
  command -v ethtool &>/dev/null || { echo "  $iface: ethtool not available — skip (run from host)"; return 0; }
  if ethtool -A "$iface" rx off tx off 2>/dev/null; then
    echo "  $iface: flow control off (ethtool)"
  else
    local pci
    pci=$(ethtool -i "$iface" 2>/dev/null | awk '/bus-info/{print $2}') || true
    if [ -n "$pci" ] && [ -f "/sys/bus/pci/devices/$pci/net/$iface/device/../../infiniband" ] 2>/dev/null; then
      echo "  $iface: ethtool -A not supported; mlx5 sysfs fallback N/A"
    else
      echo "  $iface: ethtool -A not supported (OK for in-container run; call from host)"
    fi
  fi
}

case "$ROLE" in
  lava|flame|dell|alice|bob) _fc_off "$GEN_IFACE0";  _fc_off "$GEN_IFACE1"  ;;
  dut)   _fc_off "$SERVER_KERNEL_IFACE0"; _fc_off "$SERVER_KERNEL_IFACE1" ;;
esac

echo ""
echo "[5/8] RT scheduling: unrestricted..."
echo -1 > /proc/sys/kernel/sched_rt_runtime_us 2>/dev/null || true
cur=$(cat /proc/sys/kernel/sched_rt_runtime_us 2>/dev/null || echo "?")
echo "  sched_rt_runtime_us = $cur"

echo ""
echo "[6/8] VM settings..."
sysctl -qw vm.zone_reclaim_mode=0 2>/dev/null || true
sysctl -qw vm.swappiness=0 2>/dev/null || true
echo "  vm.zone_reclaim_mode=$(sysctl -n vm.zone_reclaim_mode 2>/dev/null || echo '?')"
echo "  vm.swappiness=$(sysctl -n vm.swappiness 2>/dev/null || echo '?')"

echo ""
echo "[7/8] irqbalance..."
if systemctl is-active --quiet irqbalance 2>/dev/null; then
  systemctl stop irqbalance
  echo "  irqbalance stopped."
else
  echo "  irqbalance already inactive."
fi
systemctl disable irqbalance 2>/dev/null || true

echo ""
echo "[8/8] NIC link speed → 100 G..."

_link_100g() {
  local iface="$1"
  ip link show "$iface" &>/dev/null 2>&1 || { echo "  $iface: not found — skip"; return 0; }
  command -v ethtool &>/dev/null          || { echo "  $iface: ethtool not available — skip (run from host)"; return 0; }
  local speed
  ip link set "$iface" down 2>/dev/null || true
  ethtool -s "$iface" autoneg on 2>/dev/null || true
  ip link set "$iface" up 2>/dev/null || true
  for _i in $(seq 1 8); do
    speed=$(ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}')
    case "$speed" in
      100000Mb/s|200000Mb/s|400000Mb/s) echo "  $iface: $speed (auto-negotiated) OK"; return 0 ;;
    esac
    sleep 1
  done
  echo "  $iface: speed=${speed:-unknown} after AN wait — forcing 100 G (autoneg off)..."
  if ! ethtool -s "$iface" speed 100000 duplex full autoneg off 2>/dev/null; then
    echo "  $iface: ethtool -s failed (needs host privileges)"
    return 0
  fi
  for _i in $(seq 1 10); do
    speed=$(ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}')
    [ "$speed" = "100000Mb/s" ] && { echo "  $iface: now 100 G (after ${_i}s)"; return 0; }
    sleep 1
  done
  echo "  $iface: WARNING — still ${speed:-unknown} after 10 s"
}

case "$ROLE" in
  lava|flame|dell|alice|bob) _link_100g "$GEN_IFACE0";  _link_100g "$GEN_IFACE1"  ;;
  dut)   _link_100g "$SERVER_KERNEL_IFACE0"; _link_100g "$SERVER_KERNEL_IFACE1" ;;
esac

if [ "$ROLE" = "dut" ]; then
  echo ""
  echo "[9/9] NIC firmware: CQE_COMPRESSION=AGGRESSIVE + PCI_WR_ORDERING=1..."

  _mlx_reset_pcis=""

  _mlx_set_param() {
    local pci="$1" param="$2" want="$3"
    shift 3
    if ! command -v mlxconfig &>/dev/null; then
      echo "  mlxconfig not found — skipping (mstflint not in PATH?)"
      return 0
    fi
    local cur
    cur=$(mlxconfig -d "$pci" q 2>/dev/null | awk -v p="$param" '$0 ~ p {print $2}') || true
    if [ -z "$cur" ]; then
      echo "  $pci: $param — mlxconfig query returned nothing"
      return 0
    fi
    local v
    for v in "$@"; do
      if [ "$cur" = "$v" ]; then
        echo "  $pci: $param=$cur — OK"
        return 0
      fi
    done
    echo "  $pci: $param=$cur → setting ${want}..."
    if mlxconfig -d "$pci" -y set "${param}=${want}" 2>/dev/null; then
      echo "  $pci: $param set (firmware reset pending)"
      case " $_mlx_reset_pcis " in
        *" $pci "*) ;;
        *) _mlx_reset_pcis="${_mlx_reset_pcis:+$_mlx_reset_pcis }$pci" ;;
      esac
    else
      echo "  $pci: mlxconfig set failed"
    fi
  }

  _mlxfwreset() {
    local pci="$1"
    local mlxfw_py="/usr/lib64/mft/python_tools/mlxfwreset/mlxfwreset.py"
    if [ ! -f "$mlxfw_py" ]; then
      echo "  $pci: WARNING — mlxfwreset.py not found; changes apply on next power cycle"
      echo "    Install NVIDIA MFT on host; /usr/lib64/mft is mounted by compose.yaml."
      return 0
    fi
    echo "  $pci: mlxfwreset --level 3..."
    PYTHONPATH=/usr/lib64/mft/python_tools:/usr/lib64/mft/python_ext_libs \
      python3 "$mlxfw_py" --device "$pci" --level 3 --yes reset 2>&1 | \
      sed 's/^/    /' || echo "  $pci: mlxfwreset failed (check /usr/lib64/mft libs)"
  }

  _mlx_set_param "$DUT_PCI_LEFT"  CQE_COMPRESSION 1 "AGGRESSIVE(1)"
  _mlx_set_param "$DUT_PCI_RIGHT" CQE_COMPRESSION 1 "AGGRESSIVE(1)"
  _mlx_set_param "$DUT_PCI_LEFT"  PCI_WR_ORDERING 1 "1" "FOR_ALL_CONNECTIONS(1)"
  _mlx_set_param "$DUT_PCI_RIGHT" PCI_WR_ORDERING 1 "1" "FOR_ALL_CONNECTIONS(1)"

  if [ -n "$_mlx_reset_pcis" ]; then
    echo ""
    echo "  Firmware changes detected — running mlxfwreset to activate..."
    for _pci in $_mlx_reset_pcis; do
      _mlxfwreset "$_pci"
    done
  fi
fi

echo ""
echo "=== perf-tune done ($ROLE) ==="
echo ""
echo "NOTE (boot params): isolcpus/nohz_full/rcu_nocbs/processor.max_cstate/irqaffinity"
echo "  are applied by setup/install.sh (both DUT and generator) and need a reboot."
echo "  perf-tune.sh runs inside the container and cannot set them.  Verify with:"
echo "    tr ' ' '\\n' < /proc/cmdline | grep -E 'isolcpus|nohz_full|rcu_nocbs'"
echo "  Missing here means install.sh has not been re-run since the core count changed."
