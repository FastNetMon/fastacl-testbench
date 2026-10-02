#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail
export LC_ALL=C

HW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUT=epyc GEN=lava
. "$HW/vars.sh" >/dev/null 2>&1 || true

DPU_HOST="${DPU_HOST:-${LAB_HOST_bluefield3:?}}"
GEN_HOST="${GEN_HOST:-${LAB_HOST_lava:?}}"
HOST_REPO="${HOST_REPO:-fastacl-testbench}"
DPU_SRC="${DPU_SRC:-/home/${LAB_SSH_USER}/${HOST_REPO}}"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o ServerAliveInterval=5"
DPU="${LAB_SSH_USER}@${DPU_HOST}"; GENS="${LAB_SSH_USER}@${GEN_HOST}"
SAMPLE_SEC="${SAMPLE_SEC:-15}"
TRIALS="${DPU_TRIALS:-1}"
TARGET_MPPS="${TREX_TARGET_MPPS:-142}"
RESULTS_FILE="${RESULTS_FILE:-$HW/../../results/run.jsonl}"
CALIBRATE="${CALIBRATE:-0}"
DRIVER="${DUT_DRIVER:-dpdk}"
RDMA_MODE="${DUT_RDMA_MODE:-dv}"
RDMA_RSS="${DUT_RDMA_RSS:-}"
RXQ="${DPU_WORKERS:-12}"

vpp() { $SSH "$DPU" "docker exec bf3-vpp vppctl -s /run/vpp/cli.sock $*" 2>/dev/null | tr -d '\r'; }
say() { echo ">> $*"; }

emit() {
  mkdir -p "$(dirname "$RESULTS_FILE")"
  python3 - "$RESULTS_FILE" "$@" <<'PY'
import json, sys, time
row = {"ts": int(time.time()), "dut": "bluefield3", "gen": "lava"}
for kv in sys.argv[2:]:
    k, _, v = kv.partition("=")
    try:
        row[k] = float(v) if v.replace(".", "", 1).isdigit() else v
    except ValueError:
        row[k] = v
with open(sys.argv[1], "a") as f:
    f.write(json.dumps(row) + "\n")
PY
}

bringup_dut() {
  local setup="$1"
  say "DPU bring-up (VPP + fastacl from the licensed release bundle)"
  $SSH "$DPU" "sg docker -c 'bash ${DPU_SRC}/labs/hw/dut-image.sh'" ||
    { echo "ERROR: could not build the DUT image from the release bundle on the DPU" >&2; return 1; }
  printf '%s\n' "$setup" | $SSH "$DPU" "cat > /tmp/fastacl-dpu-setup.body"
  $SSH "$DPU" "DRIVER=$DRIVER RDMA_MODE=$RDMA_MODE RDMA_RSS=$RDMA_RSS RXQ=$RXQ SRC=${DPU_SRC} bash -s" <<'REMOTE'
set -e
conf=$SRC/labs/hw/dpu/startup-arm.conf
: > /tmp/fastacl-dpu-setup.vpp
if [ "$DRIVER" = rdma ]; then
  for p in p0 p1; do
    echo "create interface rdma host-if $p name $p num-rx-queues $RXQ rx-queue-size 4096 tx-queue-size 4096 mode $RDMA_MODE${RDMA_RSS:+ rss $RDMA_RSS}" \
      >> /tmp/fastacl-dpu-setup.vpp
  done
  awk '/^dpdk *\{/ {skip = 1} skip {if (/^\}/) skip = 0; next}
       /^plugins *\{/ {print; print "  plugin dpdk_plugin.so { disable }"; print "  plugin rdma_plugin.so { enable }"; next}
       {print}' "$conf" > /tmp/fastacl-dpu-startup.conf
else
  cp "$conf" /tmp/fastacl-dpu-startup.conf
fi
cat /tmp/fastacl-dpu-setup.body >> /tmp/fastacl-dpu-setup.vpp
REMOTE
  $SSH "$DPU" "
    echo 4096 | sudo -n tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages >/dev/null
    sudo -n ovs-vsctl del-port ovsbr1 p0 2>/dev/null; sudo -n ovs-vsctl del-port ovsbr2 p1 2>/dev/null
    docker rm -f bf3-vpp >/dev/null 2>&1
    docker run -d --name bf3-vpp --privileged --network host \
      -v ${DPU_SRC}:/src -v /tmp/fastacl-dpu-setup.vpp:/tmp/fastacl-dpu-setup.vpp \
      -v /tmp/fastacl-dpu-startup.conf:/tmp/fastacl-dpu-startup.conf \
      -v /dev/hugepages:/dev/hugepages -v /run/vpp:/run/vpp -v /dev/infiniband:/dev/infiniband \
      fastacl-dut:current bash -c '
        lic=/src/labs/hw/license/fastacl-license.json
        [ -f \$lic ] || lic=/opt/fastacl/fastacl-license.json
        cp \$lic /tmp/fastacl-lab-license.json; cp \$lic.sig /tmp/fastacl-lab-license.json.sig
        exec vpp -c /tmp/fastacl-dpu-startup.conf' >/dev/null 2>&1"
  local n=0
  for _ in $(seq 1 12); do
    sleep 5
    n=$(vpp show interface | grep -cE '^ *p[01] ')
    [ "$n" = 2 ] && break
  done
  if [ "$n" != 2 ]; then
    echo "ERROR: VPP did not bind p0/p1" >&2
    $SSH "$DPU" "docker logs --tail 40 bf3-vpp 2>&1; docker exec bf3-vpp tail -40 /tmp/vpp-bf3.log 2>&1" >&2
    return 1
  fi
  say "VPP up: $(vpp show version | head -1), driver $(driver_label)"
}

rig() {
  local cpu cores kernel nic vpp_ver plugin workers link lic_kind lic_exp gcpu gcores gnic
  cpu=$($SSH "$DPU" "lscpu | awk -F: '/Model name/{print \$2; exit}' | xargs")
  cores=$($SSH "$DPU" "grep -c ^processor /proc/cpuinfo")
  kernel=$($SSH "$DPU" "uname -r")
  dut_os=$($SSH "$DPU" 'echo "DOCA $(dpkg-query -W -f="\${Version}" doca-runtime 2>/dev/null | sed -E "s/^1-//; s/-.*//"), bf-release $(dpkg-query -W -f="\${Version}" bf-release 2>/dev/null), NIC firmware $(sudo -n flint -d 03:00.0 q 2>/dev/null | awk -F": *" "/^FW Version/{print \$2}")"')
  nic=$($SSH "$DPU" "lspci -s 03:00.0 | cut -d: -f3- | xargs")
  vpp_ver=$(vpp show version | awk '{print $2}' | head -1)
  plugin=$($SSH "$DPU" "docker exec bf3-vpp dpkg-query -W fastacl-plugin" 2>/dev/null | awk '{print $2}')
  workers=$(vpp show threads | grep -c vpp_wk_)
  link=$(vpp show hardware-interfaces p0 | awk -F': ' '/Link speed/{print $2; exit}' | sed -E 's/\.0+ / /')
  lic_kind=$(vpp show fastacl license | awk -F': *' '/^kind/{print $2}')
  lic_exp=$(vpp show fastacl license | awk -F': *' '/^expires/{print $2}')
  gcpu=$($SSH "$GENS" "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs")
  gcores=$($SSH "$GENS" "grep -c ^processor /proc/cpuinfo")
  gnic=$($SSH "$GENS" "lspci -s ${SENDER_PCI#0000:} | cut -d: -f3- | xargs")
  emit bench=rig dut_cpu="BlueField-3 Arm ${cpu:-Cortex-A78AE}" dut_cores="$cores" \
    dut_kernel="$kernel" dut_os="$dut_os" dut_nic="$nic" link_speed="$link" gen_cpu="$gcpu" gen_cores="$gcores" \
    gen_nic="$gnic" vpp_version="$vpp_ver" plugin_version="$plugin" vpp_workers="$workers" rx_desc=4096 tx_desc=4096 \
    trex_version="${TREX_VERSION:-3.06}" target_mpps="$TARGET_MPPS" licence="$lic_kind" \
    licence_expires="$lic_exp" dut_driver="$(driver_label)" verdict=INFO
  say "rig: ${cpu} x${cores}, $nic, $link; VPP $vpp_ver ($workers workers, $(driver_label)); fastacl $plugin"
}

gen_alive() {
  [ "$($SSH "$GENS" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1); \
    [ -n \"\$CID\" ] && sg docker -c \"docker exec \$CID sh -c 'ps -o stat= -C _t-rex-64 | grep -q ^[^Z]'\" && echo yes" \
    2>/dev/null)" = yes ]
}

start_gen() {
  local size="$1" attack="$2" mpps="$TARGET_MPPS"
  [ "$size" -gt 64 ] && mpps=0
  $SSH "$GENS" "cd ~/${HOST_REPO}; sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1
     GEN=lava DUT=epyc TREX_PKTSIZE=$size TREX_ATTACK=$attack TREX_TARGET_MPPS=$mpps \
       sg docker -c 'docker compose -f labs/hw/compose.yaml run -d gen'" >/dev/null 2>&1
  for _ in $(seq 1 12); do
    sleep 10
    gen_alive && { sleep 20; return 0; }
  done
  echo "ERROR: generator did not start (size $size, $attack)" >&2; return 1
}

switch_attack() {
  $SSH "$GENS" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1)
     sg docker -c \"docker exec -e TREX_ATTACK=$1 \$CID python3 /src/labs/hw/gen/conf/switch.py $1\"" >/dev/null 2>&1
  sleep 6
}

driver_label() { [ "$DRIVER" = rdma ] && echo "rdma $RDMA_MODE" || echo dpdk; }

rx_good() {
  if [ "$DRIVER" = rdma ]; then
    vpp show interface p1 | awk '/rx packets/ {print $NF; exit}'
  else
    vpp show hardware p1 | awk '/rx_good_packets/{print $2}'
  fi
}

nic_phy() { $SSH "$DPU" "sudo -n ethtool -S p1" 2>/dev/null | awk '$1 == "rx_packets_phy:" {print $2}'; }

teardown() {
  say "teardown: stop VPP, restore OVS, stop gen"
  $SSH "$DPU" "docker rm -f bf3-vpp >/dev/null 2>&1; sudo -n ovs-vsctl add-port ovsbr1 p0 2>/dev/null; sudo -n ovs-vsctl add-port ovsbr2 p1 2>/dev/null" || true
  $SSH "$GENS" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1" || true
}

gen_param() {
  $SSH "$GENS" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1)
     sg docker -c \"docker exec \$CID sh -c 'echo $2 > /tmp/$1'\"" >/dev/null 2>&1
}
