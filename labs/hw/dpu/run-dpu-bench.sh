#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail
export LC_ALL=C

HW="$(cd "$(dirname "$0")/.." && pwd)"
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
FRAMES="${DPU_FRAME_SIZES:-64 imix 1500}"
TARGET_MPPS="${TREX_TARGET_MPPS:-142}"
RESULTS_FILE="${RESULTS_FILE:-$HW/../../results/run.jsonl}"
FLOOR_64="${FLOOR_64:-45}"; FLOOR_imix="${FLOOR_IMIX:-28}"; FLOOR_1500="${FLOOR_1500:-7}"
CALIBRATE="${CALIBRATE:-0}"

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
  say "DPU bring-up (VPP + fastacl from the licensed release bundle)"
  $SSH "$DPU" "sg docker -c 'bash ${DPU_SRC}/labs/hw/dut-image.sh'" ||
    { echo "ERROR: could not build the DUT image from the release bundle on the DPU" >&2; return 1; }
  $SSH "$DPU" "sed -e 's|__IF_LEFT__|p0|g' -e 's|__IF_RIGHT__|p1|g' \
     ${DPU_SRC}/labs/hw/dut/conf/setup.vpp > /tmp/fastacl-dpu-setup.vpp"
  $SSH "$DPU" "
    echo 4096 | sudo -n tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages >/dev/null
    sudo -n ovs-vsctl del-port ovsbr1 p0 2>/dev/null; sudo -n ovs-vsctl del-port ovsbr2 p1 2>/dev/null
    docker rm -f bf3-vpp >/dev/null 2>&1
    docker run -d --name bf3-vpp --privileged --network host \
      -v ${DPU_SRC}:/src -v /tmp/fastacl-dpu-setup.vpp:/tmp/fastacl-dpu-setup.vpp \
      -v /dev/hugepages:/dev/hugepages -v /run/vpp:/run/vpp -v /dev/infiniband:/dev/infiniband \
      fastacl-dut:current bash -c '
        lic=/src/labs/hw/license/fastacl-license.json
        [ -f \$lic ] || lic=/opt/fastacl/fastacl-license.json
        cp \$lic /tmp/fastacl-lab-license.json; cp \$lic.sig /tmp/fastacl-lab-license.json.sig
        exec vpp -c /src/labs/hw/dpu/startup-arm.conf' >/dev/null 2>&1"
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
  say "VPP up: $(vpp show version | head -1)"
}

rig() {
  local cpu cores kernel nic vpp_ver plugin workers link lic_kind lic_exp gcpu gcores gnic
  cpu=$($SSH "$DPU" "lscpu | awk -F: '/Model name/{print \$2; exit}' | xargs")
  cores=$($SSH "$DPU" "grep -c ^processor /proc/cpuinfo")
  kernel=$($SSH "$DPU" "uname -r")
  dut_os=$($SSH "$DPU" "cat /etc/mlnx-release 2>/dev/null")
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
    licence_expires="$lic_exp" verdict=INFO
  say "rig: ${cpu} x${cores}, $nic, $link; VPP $vpp_ver ($workers workers); fastacl $plugin"
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

rx_good() { vpp show hardware p1 | awk '/rx_good_packets/{print $2}'; }

measure_drop_mpps() {
  vpp fastacl rule del all >/dev/null; vpp fastacl rule add order 10 proto 17 action drop >/dev/null
  sleep 4
  local g0 g1 t0 t1
  vpp clear runtime >/dev/null
  g0=$(rx_good); t0=$(date +%s.%N)
  sleep "$SAMPLE_SEC"
  g1=$(rx_good); t1=$(date +%s.%N)
  local cyc
  cyc=$(vpp show runtime | awk '$1 ~ /^fastacl-filter/ {v += $4; c += $4 * $6} END {if (v) printf "%.1f", c / v}')
  awk -v a="${g0:-0}" -v b="${g1:-0}" -v s="$t0" -v e="$t1" -v c="${cyc:-}" \
    'BEGIN{printf "%.1f %s", (b-a)/(e-s)/1e6, c}'
}

measure_trials() {
  local i out=""
  for i in $(seq 1 "$TRIALS"); do
    out+="$(measure_drop_mpps)"$'\n'
  done
  printf '%s' "$out" | sort -n -k1,1 | awk '
    {m[NR] = $1; c[NR] = $2}
    END {k = int((NR + 1) / 2); printf "%s %s %s %s", m[k], c[k], m[1], m[NR]}'
}

record() {
  local frame="$1" attack="$2" mpps cyc lo hi floor verdict=INFO
  read -r mpps cyc lo hi <<<"$3"
  floor=$(eval "echo \${FLOOR_$frame:-}")
  if [ -n "$floor" ] && [ "$CALIBRATE" != 1 ]; then
    if awk -v m="$mpps" -v f="$floor" 'BEGIN{exit !(m >= f)}'; then verdict=PASS; else verdict=FAIL; rc=1; fi
  fi
  echo "  $frame drop: $mpps Mpps (median of $TRIALS, range ${lo:-$mpps}-${hi:-$mpps}), ${cyc:--} ticks/pkt (floor ${floor:--}) $verdict"
  emit bench=dpu scenario="udp drop ${frame}" frame="$frame" attack="$attack" rules=1 \
    dut_mpps="$mpps" mpps_min="${lo:-$mpps}" mpps_max="${hi:-$mpps}" trials="$TRIALS" \
    cyc_pkt="${cyc:-}" floor="${floor:-}" verdict="$verdict"
}

teardown() {
  say "teardown: stop VPP, restore OVS, stop gen"
  $SSH "$DPU" "docker rm -f bf3-vpp >/dev/null 2>&1; sudo -n ovs-vsctl add-port ovsbr1 p0 2>/dev/null; sudo -n ovs-vsctl add-port ovsbr2 p1 2>/dev/null" || true
  $SSH "$GENS" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1" || true
}
trap teardown EXIT

rc=0
if ! bringup_dut; then
  emit bench=load scenario="dpu bring-up" verdict=FAIL
  exit 1
fi
rig
for f in $FRAMES; do
  say "=== $f ==="
  if [ "$f" = imix ]; then
    start_gen 64 cold-scan-imix && switch_attack cold-scan-imix && record imix cold-scan-imix "$(measure_trials)"
  else
    start_gen "$f" udp-rand && switch_attack udp-rand && record "$f" udp-rand "$(measure_trials)"
  fi || { emit bench=load scenario="generator $f" verdict=FAIL; rc=1; }
done

echo; [ "$rc" = 0 ] && echo "DPU BENCH PASSED" || echo "DPU BENCH FAILED"
exit $rc
