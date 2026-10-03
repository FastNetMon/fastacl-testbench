#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$LAB_DIR/vars.sh"
source "$LAB_DIR/../common/vpp.sh"

echo "=== FastACL DUT ==="
echo "  eth-left:  $DUT_LEFT_IP/$DUT_LEFT_PREFIX  (PCI: $DUT_PCI_LEFT)  [fastacl enabled]"
echo "  eth-right: $DUT_RIGHT_IP/$DUT_RIGHT_PREFIX  (PCI: $DUT_PCI_RIGHT)"
echo "  Workers:   cores $DUT_WORKER_CORES"
echo ""

vpp_ensure_hugepages

HP2M_FILE="/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"
HP2M_HEAP=6144
HP2M_NEED=$((3072 + HP2M_HEAP + (${DUT_POLL_WORKERS:-32} > 32
				   ? (${DUT_POLL_WORKERS:-32} - 32) * 192
				   : 0)))
if ! pgrep -x vpp >/dev/null 2>&1; then
  stale=$(ls /dev/hugepages/rtemap_* /dev/hugepages1G/rtemap_* 2>/dev/null | wc -l)
  if [ "$stale" -gt 0 ]; then
    echo "Clearing ${stale} stale hugepage map(s) from a previous run..."
    rm -f /dev/hugepages/rtemap_* /dev/hugepages1G/rtemap_* 2>/dev/null || true
  fi
else
  echo "  NOTE: a vpp process is already running — leaving hugepage maps alone."
fi

vpp_ensure_hugepages_2m "$HP2M_NEED"
free_2m=$(awk '/HugePages_Free/ {print $2}' /proc/meminfo)
echo "  2 MB hugepages free: ${free_2m}"
if [ "${free_2m:-0}" -lt "$HP2M_HEAP" ]; then
  echo "  WARNING: fewer free 2 MB pages than the main heap needs" \
       "(${free_2m} < ${HP2M_HEAP}) — VPP will fail to allocate its heap."
fi

"$LAB_DIR/setup/perf-tune.sh" dut
echo ""

echo "Ensuring CQE_COMPRESSION=AGGRESSIVE on DUT NICs..."
vpp_ensure_cqe_aggressive "$DUT_PCI_LEFT" "$DUT_PCI_RIGHT"
echo ""

if [ "$DPDK_DRIVER" = "mlx5" ]; then
  for _pci in "$DUT_PCI_LEFT" "$DUT_PCI_RIGHT"; do
    _cur_drv=$(readlink /sys/bus/pci/devices/"$_pci"/driver 2>/dev/null | xargs basename 2>/dev/null || echo "")
    if [ "$_cur_drv" = "vfio-pci" ]; then
      echo "  Re-binding $_pci: vfio-pci → mlx5_core"
      echo "" > /sys/bus/pci/devices/"$_pci"/driver_override 2>/dev/null || true
    fi
    echo "  Rebinding $_pci: mlx5_core (clean state)"
    echo "$_pci" > /sys/bus/pci/devices/"$_pci"/driver/unbind 2>/dev/null || true
    sleep 0.5
    echo "$_pci" > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || \
      { echo "  WARNING: could not bind $_pci to mlx5_core; trying probe"; echo "$_pci" > /sys/bus/pci/drivers_probe 2>/dev/null || true; }
    sleep 0.5
  done
elif [ "$DPDK_DRIVER" = "vfio-pci" ]; then
  echo "vfio-pci mode: binding NICs to vfio-pci..."
  modprobe vfio-pci 2>/dev/null || true
  for _pf_pci in "$DUT_PCI_LEFT" "$DUT_PCI_RIGHT"; do
    _cur=$(cat /sys/bus/pci/devices/"$_pf_pci"/sriov_numvfs 2>/dev/null || echo 0)
    if [ "$_cur" != "0" ]; then
      echo 0 > /sys/bus/pci/devices/"$_pf_pci"/sriov_numvfs 2>/dev/null || true
    fi
  done
  for _pci in "$DUT_PCI_LEFT" "$DUT_PCI_RIGHT"; do
    _cur_drv=$(readlink /sys/bus/pci/devices/"$_pci"/driver 2>/dev/null | xargs basename 2>/dev/null || echo "")
    if [ "$_cur_drv" = "vfio-pci" ]; then
      echo "  $_pci already on vfio-pci"
    else
      echo "  $_pci: $_cur_drv → vfio-pci"
      [ -n "$_cur_drv" ] && echo "$_pci" > /sys/bus/pci/devices/"$_pci"/driver/unbind 2>/dev/null || true
      echo "vfio-pci" > /sys/bus/pci/devices/"$_pci"/driver_override 2>/dev/null
      echo "$_pci" > /sys/bus/pci/drivers/vfio-pci/bind || \
        { echo "  ERROR: cannot bind $_pci to vfio-pci"; exit 1; }
    fi
  done
  echo "  vfio-pci binding complete."
  echo ""
elif [ -n "${DUT_PCI_LEFT_PF:-}" ] && [ "$DUT_PCI_LEFT" != "$DUT_PCI_LEFT_PF" ]; then
  echo "SR-IOV mode: ensuring VFs exist on ${DUT_PCI_LEFT_PF} / ${DUT_PCI_RIGHT_PF}..."
  _pf_left_iface=$(ls /sys/bus/pci/devices/"${DUT_PCI_LEFT_PF}"/net/  2>/dev/null | head -1)
  _pf_right_iface=$(ls /sys/bus/pci/devices/"${DUT_PCI_RIGHT_PF}"/net/ 2>/dev/null | head -1)
  for _pf_pci in "${DUT_PCI_LEFT_PF}" "${DUT_PCI_RIGHT_PF}"; do
    _cur=$(cat /sys/bus/pci/devices/"$_pf_pci"/sriov_numvfs 2>/dev/null || echo 0)
    if [ "$_cur" = "0" ]; then
      echo 1 > /sys/bus/pci/devices/"$_pf_pci"/sriov_numvfs || \
        { echo "  ERROR: cannot create VF on $_pf_pci"; exit 1; }
    fi
  done
  [ -n "$_pf_left_iface"  ] && ip link set "$_pf_left_iface"  vf 0 mac "$DUT_LEFT_MAC"    trust on 2>/dev/null || true
  [ -n "$_pf_right_iface" ] && ip link set "$_pf_right_iface" vf 0 mac "$DUT_VF_RIGHT_MAC" trust on 2>/dev/null || true
  ip link set dev "$SERVER_KERNEL_IFACE0" address "$DUT_LEFT_MAC"    2>/dev/null || true
  ip link set dev "$SERVER_KERNEL_IFACE1" address "$DUT_VF_RIGHT_MAC" 2>/dev/null || true
  echo "  VF eth-left:  ${DUT_PCI_LEFT}  MAC ${DUT_LEFT_MAC}"
  echo "  VF eth-right: ${DUT_PCI_RIGHT}  MAC $DUT_VF_RIGHT_MAC"
  echo ""
fi

echo "IRQ affinity: managed by kernel (see install.sh for isolcpus cmdline)"

CONF_DIR="$SCRIPT_DIR/conf"
RUNTIME_CONF="/tmp/fastacl-dut-startup.conf"
RUNTIME_SETUP="/tmp/fastacl-dut-setup.vpp"

PLUGIN_PATH="$VPP_PLUGIN_PATH"
if [ -n "$FASTACL_PLUGIN_PATH" ]; then
  PLUGIN_PATH="$FASTACL_PLUGIN_PATH:$VPP_PLUGIN_PATH"
fi

sed -e "s|__DUT_PCI_LEFT__|$DUT_PCI_LEFT|g" \
    -e "s|__DUT_PCI_RIGHT__|$DUT_PCI_RIGHT|g" \
    -e "s|__DUT_MAIN_CORE__|$DUT_MAIN_CORE|g" \
    -e "s|__DUT_WORKER_CORES__|$DUT_WORKER_CORES|g" \
    -e "s|__DUT_NUM_QUEUES__|$DUT_NUM_QUEUES|g" \
    -e "s|__DUT_HEAP_PAGE__|${DUT_HEAP_PAGE:-2M}|g" \
    -e "s|__DUT_BUFFERS_PER_NUMA__|${DUT_BUFFERS_PER_NUMA:-2097152}|g" \
    -e "s|__DUT_RX_DESC__|$DUT_RX_DESC|g" \
    -e "s|__DUT_TX_DESC__|$DUT_TX_DESC|g" \
    -e "s|__DUT_TSS_WORKERS__|$DUT_TSS_WORKERS|g" \
    -e "s|__DUT_DEVARGS__|$DUT_DEVARGS|g" \
    -e "s|__VPP_PLUGIN_PATH__|$PLUGIN_PATH|g" \
    -e "s|/src/labs/hw/dut/conf/setup.vpp|$RUNTIME_SETUP|g" \
    "$CONF_DIR/startup.conf" > "$RUNTIME_CONF"

sed -e "s|__IF_LEFT__|eth-left|g" \
    -e "s|__IF_RIGHT__|eth-right|g" \
    -e "s|__DUT_LEFT_IP__|$DUT_LEFT_IP|g" \
    -e "s|__DUT_LEFT_PREFIX__|$DUT_LEFT_PREFIX|g" \
    -e "s|__DUT_RIGHT_IP__|$DUT_RIGHT_IP|g" \
    -e "s|__DUT_RIGHT_PREFIX__|$DUT_RIGHT_PREFIX|g" \
    -e "s|__RECEIVER_MAC__|$RECEIVER_MAC|g" \
    "$CONF_DIR/setup.vpp" > "$RUNTIME_SETUP"

if [ "${DUT_DRIVER:-dpdk}" = rdma ]; then
  _ifl=$(ls /sys/bus/pci/devices/"$DUT_PCI_LEFT"/net 2>/dev/null | head -1)
  _ifr=$(ls /sys/bus/pci/devices/"$DUT_PCI_RIGHT"/net 2>/dev/null | head -1)
  [ -n "$_ifl" ] && [ -n "$_ifr" ] || { echo "ERROR: no kernel netdev for $DUT_PCI_LEFT / $DUT_PCI_RIGHT" >&2; exit 1; }
  ip link set "$_ifl" up; ip link set "$_ifr" up
  echo "NIC driver: VPP rdma (${DUT_RDMA_MODE:-dv}) on $_ifl / $_ifr"
  awk '/^dpdk *\{/ {skip = 1} skip {if (/^\}/) skip = 0; next}
       /^plugins *\{/ {print; print "  plugin dpdk_plugin.so { disable }"; print "  plugin rdma_plugin.so { enable }"; next}
       {print}' "$RUNTIME_CONF" > "$RUNTIME_CONF.rdma" && mv "$RUNTIME_CONF.rdma" "$RUNTIME_CONF"
  {
    for _p in "eth-left $_ifl" "eth-right $_ifr"; do
      read -r _n _i <<<"$_p"
      echo "create interface rdma host-if $_i name $_n num-rx-queues $DUT_NUM_QUEUES rx-queue-size $DUT_RX_DESC tx-queue-size $DUT_TX_DESC mode ${DUT_RDMA_MODE:-dv}"
    done
    cat "$RUNTIME_SETUP"
  } > "$RUNTIME_SETUP.rdma" && mv "$RUNTIME_SETUP.rdma" "$RUNTIME_SETUP"
fi

vpp_pre_start /run/vpp/cli.sock /run/vpp/api.sock /run/vpp/stats.sock

echo "Checking NIC firmware state..."
_PF_LEFT="${DUT_PCI_LEFT_PF:-$DUT_PCI_LEFT}"
_PF_RIGHT="${DUT_PCI_RIGHT_PF:-$DUT_PCI_RIGHT}"
NIC_STUCK=0
if [ "$DPDK_DRIVER" = "vfio-pci" ]; then
  echo "  vfio-pci mode: kernel net/ absent by design — skipping firmware net-dir check."
  echo "  If VPP fails to probe the device below, power-cycle the server."
else
for PCI in "$_PF_LEFT" "$_PF_RIGHT"; do
  NET_DIR="/sys/bus/pci/devices/$PCI/net"
  if [ ! -d "$NET_DIR" ] || [ -z "$(ls "$NET_DIR" 2>/dev/null)" ]; then
    echo "  WARNING: $PCI has no kernel net interface — mlx5 firmware may be stuck."
    NIC_STUCK=1
  else
    IFACE=$(ls "$NET_DIR" | head -1)
    echo "  $PCI → $IFACE (OK)"
  fi
done
fi
if [ "$NIC_STUCK" = "1" ]; then
  if command -v mlxfwreset &>/dev/null; then
    echo "  Running mlxfwreset to recover NIC firmware..."
    for PCI in "$_PF_LEFT" "$_PF_RIGHT"; do
      mlxfwreset --device "$PCI" --level 3 --yes reset 2>&1 || true
      [ -e "/sys/bus/pci/devices/$PCI/driver" ] || \
        echo "$PCI" > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true
    done
    echo "  mlxfwreset done. Waiting for firmware re-init..."
    for i in $(seq 1 15); do
      ALL_OK=1
      for PCI in "$_PF_LEFT" "$_PF_RIGHT"; do
        NET_DIR="/sys/bus/pci/devices/$PCI/net"
        [ -d "$NET_DIR" ] && [ -n "$(ls "$NET_DIR" 2>/dev/null)" ] || ALL_OK=0
      done
      [ "$ALL_OK" = "1" ] && break
      sleep 1
    done
    NIC_STUCK=0
    for PCI in "$_PF_LEFT" "$_PF_RIGHT"; do
      NET_DIR="/sys/bus/pci/devices/$PCI/net"
      if [ ! -d "$NET_DIR" ] || [ -z "$(ls "$NET_DIR" 2>/dev/null)" ]; then
        echo "  ERROR: $PCI still stuck after mlxfwreset — cannot start VPP."
        NIC_STUCK=1
      fi
    done
  fi
  if [ "$NIC_STUCK" = "1" ]; then
    echo ""
    echo "FATAL: CX5 NIC firmware stuck in pre-init state."
    echo "  Warm reset does NOT clear this.  Fix: POWER CYCLE the server."
    echo "  Use: ./labs/hw/setup/ipmi.sh cycle   (or power-off → power-on via IPMI)"
    exit 1
  fi
fi

echo "RSS key from vars.sh: ${DUT_RSS_KEY:0:16}..."
echo "$DUT_RSS_KEY" > /tmp/fastacl-rss-key

for _q in $(seq 0 $((DUT_NUM_QUEUES - 1))); do
  printf "set interface rx-placement eth-left  queue %d worker %d\n" "$_q" "$_q"
  printf "set interface rx-placement eth-right queue %d worker %d\n" "$_q" "$_q"
done >> "$RUNTIME_SETUP"

LAB_LICENSE=/tmp/fastacl-lab-license.json
rm -f "$LAB_LICENSE" "$LAB_LICENSE.sig"
for cand in /src/labs/hw/license/fastacl-license.json /opt/fastacl/fastacl-license.json; do
  if [ -f "$cand" ] && [ -f "$cand.sig" ]; then
    cp "$cand" "$LAB_LICENSE"
    cp "$cand.sig" "$LAB_LICENSE.sig"
    echo "Licence: $cand"
    break
  fi
done
[ -f "$LAB_LICENSE" ] || echo "WARNING: no licence found — fastacl will stay disarmed"

echo "Starting VPP..."
$VPP_BIN -c "$RUNTIME_CONF" </dev/null &
VPP_PID=$!

graceful_stop() {
  echo "Stopping VPP gracefully (SIGTERM, waiting for orderly DPDK teardown)..."
  kill -TERM "$VPP_PID" 2>/dev/null || true
  wait "$VPP_PID" 2>/dev/null || true
  echo "VPP stopped (clean exit)."
}
trap graceful_stop TERM INT

echo "Waiting for VPP CLI..."
for _i in $(seq 1 180); do
  if [ -S /run/vpp/cli.sock ] && \
     $VPPCTL_BIN show version &>/dev/null 2>&1; then
    break
  fi
  if [ "$_i" = "180" ]; then
    echo "ERROR: VPP CLI not ready after 180 s." >&2
    kill "$VPP_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

echo "Checking rx-placement..."
PLACEMENT=$($VPPCTL_BIN show interface rx-placement 2>/dev/null || echo "")
LEFT_Q=$(echo "$PLACEMENT"  | grep -c "eth-left"  || true)
RIGHT_Q=$(echo "$PLACEMENT" | grep -c "eth-right" || true)
if [ "$LEFT_Q" = "$DUT_NUM_QUEUES" ] && [ "$RIGHT_Q" = "$DUT_NUM_QUEUES" ]; then
  echo "  rx-placement OK: eth-left $LEFT_Q queues, eth-right $RIGHT_Q queues."
else
  echo "  WARNING: eth-left $LEFT_Q/$DUT_NUM_QUEUES, eth-right $RIGHT_Q/$DUT_NUM_QUEUES queues assigned."
fi

echo "Pinning eth-left MAC to $DUT_LEFT_MAC..."
$VPPCTL_BIN set interface mac address eth-left "$DUT_LEFT_MAC" 2>/dev/null \
  && echo "  done" || echo "  (skipped — PMD may not support runtime MAC set)"

if [ -z "${_FASTACL_INGRESS_AUTODETECTED:-}" ]; then
  _rxphy() { local v; v=$($VPPCTL_BIN show hardware "$1" 2>/dev/null | awk '/rx_phy_packets/{print $NF; exit}'); v=${v//[^0-9]/}; echo "${v:-0}"; }
  _l0=$(_rxphy eth-left); _r0=$(_rxphy eth-right); sleep 2
  _l1=$(_rxphy eth-left); _r1=$(_rxphy eth-right)
  _ld=$(( _l1 - _l0 )); _rd=$(( _r1 - _r0 ))
  echo "Cabling autodetect: eth-left +${_ld}, eth-right +${_rd} rx_phy pkts/2s"
  if [ "$_rd" -gt 2000000 ] && [ "$_rd" -gt $(( _ld * 4 + 1000000 )) ]; then
    echo "  >>> Flood is arriving on the SINK port — cabling swapped; re-pointing ingress."
    echo "  Re-exec dut/start.sh with DUT_INGRESS_PORT=$DUT_PCI_RIGHT_PF (was $DUT_PCI_LEFT_PF)"
    kill -TERM "$VPP_PID" 2>/dev/null || true; wait "$VPP_PID" 2>/dev/null || true
    export DUT_INGRESS_PORT="$DUT_PCI_RIGHT_PF" _FASTACL_INGRESS_AUTODETECTED=1
    exec "$0" "$@"
  fi
  echo "  Ingress OK (or no traffic yet) — eth-left = $DUT_PCI_LEFT stays the FastACL ingress."
fi

echo "Programming NIC RSS key..."
if [ "$DPDK_DRIVER" = "vfio-pci" ]; then
  echo "  vfio-pci mode: no kernel interface — using firmware default key."
  echo "  Ensure vars.sh DUT_RSS_KEY matches the NIC's firmware default RSS key."
elif [ -n "$DUT_RSS_KEY" ] && command -v ethtool &>/dev/null; then
  _key_colon=$(echo "$DUT_RSS_KEY" | sed 's/../&:/g; s/:$//')
  if ethtool -X "$SERVER_KERNEL_IFACE0" hkey "$_key_colon" 2>/dev/null; then
    echo "  NIC $SERVER_KERNEL_IFACE0 RSS key set: ${DUT_RSS_KEY:0:16}..."
  else
    echo "  WARNING: ethtool -X failed — NIC uses firmware default key"
    echo "  (attacks.py still uses vars.sh key; distribution may be off)"
  fi
else
  echo "  Skipped (no DUT_RSS_KEY or ethtool unavailable)"
fi

wait "$VPP_PID"
