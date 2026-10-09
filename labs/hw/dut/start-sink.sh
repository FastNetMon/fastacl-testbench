#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$LAB_DIR/vars.sh"
source "$LAB_DIR/../common/vpp.sh"

[ -n "${SINK_PORTS:-}" ] || { echo "ERROR: SINK_PORTS is empty (DUT=$DUT)" >&2; exit 1; }

nodes=$(ls -d /sys/devices/system/node/node[0-9]* | wc -l)
if [ -n "${SINK_NUMA_NODES:-}" ] && [ "$nodes" != "$SINK_NUMA_NODES" ]; then
  echo "WARNING: $nodes NUMA node(s), this rig expects $SINK_NUMA_NODES (BIOS: labs/hw/setup/bios-numa.py)"
fi

workers=0
for e in $SINK_PORTS; do workers=$((workers + $(cut -d: -f5 <<<"$e"))); done
echo "=== FastACL sink: every port ingress, $workers workers ==="

vpp_ensure_hugepages
if ! pgrep -x vpp >/dev/null 2>&1; then
  rm -f /dev/hugepages/rtemap_* /dev/hugepages1G/rtemap_* 2>/dev/null || true
fi
vpp_ensure_hugepages_2m $((3072 + 6144 + (workers > 32 ? (workers - 32) * 192 : 0)))

"$LAB_DIR/setup/perf-tune.sh" dut
echo ""

for f in $SINK_FORCE_100G; do
  [ "$(cat /sys/class/net/$f/carrier 2>/dev/null)" = 1 ] && continue
  echo "  $f: no link, forcing 100G with autonegotiation off"
  ethtool -s "$f" speed 100000 duplex full autoneg off || true
done

CONF=/tmp/fastacl-sink-startup.conf
SETUP=/tmp/fastacl-sink-setup.vpp
{
  cat <<EOF
unix {
  cli-listen /run/vpp/cli.sock
  log /tmp/vpp-dut.log
  startup-config $SETUP
  nodaemon
}
socksvr { socket-name /run/vpp/api.sock }
api-segment { prefix fastacl-dut }
memory {
  main-heap-size 12G
  main-heap-page-size ${DUT_HEAP_PAGE:-2M}
}
cpu {
  main-core $DUT_MAIN_CORE
  corelist-workers ${SINK_CORELIST:-1-$workers}
}
buffers { buffers-per-numa ${DUT_BUFFERS_PER_NUMA:-2097152} }
plugins {
  path $VPP_PLUGIN_PATH
  plugin fastacl_plugin.so { enable }
}
fastacl {
  tss-bihash-buckets 1048576
  license-file /tmp/fastacl-lab-license.json
}
statseg {
  socket-name /run/vpp/stats.sock
  size 2G
}
dpdk {
  no-multi-seg
  no-tx-checksum-offload
EOF
  for e in $SINK_PORTS; do
    IFS=: read -r d b f name q _ <<<"$e"
    echo "  dev $d:$b:$f { name $name num-rx-queues $q num-tx-queues 1 num-rx-desc $DUT_RX_DESC num-tx-desc 1024 rss { ipv4 ipv6 l3-src-only } devargs $DUT_DEVARGS }"
  done
  echo "}"
} > "$CONF"

if [ "${DUT_DRIVER:-dpdk}" = rdma ]; then
  awk '/^dpdk *\{/ {skip = 1} skip {if (/^\}/) skip = 0; next}
       /^plugins *\{/ {print; print "  plugin dpdk_plugin.so { disable }"; print "  plugin rdma_plugin.so { enable }"; next}
       {print}' "$CONF" > "$CONF.rdma" && mv "$CONF.rdma" "$CONF"
fi

w=0
{
  if [ "${DUT_DRIVER:-dpdk}" = rdma ]; then
    for e in $SINK_PORTS; do
      IFS=: read -r _ _ _ name q iface <<<"$e"
      ip link set "$iface" up
      echo "create interface rdma host-if $iface name $name num-rx-queues $q rx-queue-size $DUT_RX_DESC tx-queue-size 1024 mode ${DUT_RDMA_MODE:-dv}"
      # rdma picks a random MAC and only steers frames sent to it; use the port's own.
      echo "set interface mac address $name $(cat /sys/class/net/$iface/address)"
    done
  fi
  for e in $SINK_PORTS; do
    IFS=: read -r _ _ _ name _ _ <<<"$e"
    echo "set interface state $name up"
    if [ "${SINK_ACL:-1}" = 1 ]; then echo "set interface fastacl $name"; fi
  done
  # Workers take the queues port by port, in SINK_ORDER (names) or SINK_PORTS order.
  for name in ${SINK_ORDER:-$(for e in $SINK_PORTS; do cut -d: -f4 <<<"$e"; done)}; do
    q=$(for e in $SINK_PORTS; do IFS=: read -r _ _ _ n c _ <<<"$e"; if [ "$n" = "$name" ]; then echo "$c"; fi; done)
    for i in $(seq 0 $((q - 1))); do
      echo "set interface rx-placement $name queue $i worker $w"
      w=$((w + 1))
    done
  done
} > "$SETUP"
[ "${SINK_ACL:-1}" = 1 ] || sed -i 's/plugin fastacl_plugin.so { enable }/plugin fastacl_plugin.so { disable }/; /^fastacl {/,/^}/d' "$CONF"
[ -z "${SINK_BUFFERS_EXTRA:-}" ] || sed -i "s|^buffers { buffers-per-numa \([0-9]*\) }|buffers { buffers-per-numa \1 $SINK_BUFFERS_EXTRA }|" "$CONF"

LIC=/tmp/fastacl-lab-license.json
rm -f "$LIC" "$LIC.sig"
for cand in /src/labs/hw/license/fastacl-license.json /opt/fastacl/fastacl-license.json; do
  if [ -f "$cand" ] && [ -f "$cand.sig" ]; then cp "$cand" "$LIC"; cp "$cand.sig" "$LIC.sig"; echo "Licence: $cand"; break; fi
done

vpp_pre_start /run/vpp/cli.sock /run/vpp/api.sock /run/vpp/stats.sock
echo "Starting VPP..."
$VPP_BIN -c "$CONF" </dev/null &
VPP_PID=$!
trap 'kill -TERM $VPP_PID 2>/dev/null; wait $VPP_PID 2>/dev/null' TERM INT

for _i in $(seq 1 400); do
  $VPPCTL_BIN show version >/dev/null 2>&1 && break
  kill -0 "$VPP_PID" 2>/dev/null || { echo "ERROR: VPP exited"; tail -20 /tmp/vpp-dut.log; exit 1; }
  [ "$_i" = 400 ] && { echo "ERROR: VPP CLI not ready after 400 s" >&2; exit 1; }
  sleep 1
done
$VPPCTL_BIN show interface rx-placement | grep -c queue | xargs echo "rx queues placed:"
echo "SINK READY"
wait "$VPP_PID"
