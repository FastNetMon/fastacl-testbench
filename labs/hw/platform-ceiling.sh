#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)
set -uo pipefail
export LC_ALL=C
HW="$(cd "$(dirname "$0")" && pwd)"
. "$HW/vars.sh" >/dev/null 2>&1
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15"
RESULTS_FILE="${RESULTS_FILE:-$HW/../../results/run.jsonl}"
REPO="~/${HOST_REPO:-fastacl-testbench}"
SECS="${PLATFORM_SECS:-20}"
TRIALS="${PLATFORM_TRIALS:-3}"
SIZE="${PLATFORM_SIZE:-64}"
MULT="${PLATFORM_MULT:-100%}"
STAGES="${PLATFORM_STAGES:-cx7-1:0 cx7-2:1 cx5-1:2,3 cx5-23:4,5 cx7x2:0,1 cx7x2+cx5-1:0,1,2,3 all:0,1,2,3,4,5}"
DUT_SSH="$LAB_SSH_USER@$DUT_HOST"
GEN_SSH="$LAB_SSH_USER@$SENDER_HOST"
read -r -a SINK <<<"$SINK_PORTS"

dut_c() { $SSH "$DUT_SSH" "docker exec hw-dut-sink $1"; }
gen_c() { $SSH "$GEN_SSH" "docker exec \$(docker ps -q --filter name=hw-gen | head -1) $1"; }

dut_up() {
  $SSH "$DUT_SSH" "sg docker -c 'docker ps -aq --filter name=hw-dut | xargs -r docker rm -f' >/dev/null 2>&1
    cd $REPO && DUT=$DUT DUT_RX_DESC=${DUT_RX_DESC:-} DUT_DRIVER=${DUT_DRIVER:-dpdk} SINK_CORELIST=${SINK_CORELIST:-} DUT_BUFFERS_PER_NUMA=${DUT_BUFFERS_PER_NUMA:-} DUT_DEVARGS='${DUT_DEVARGS:-}' SINK_PORTS='$SINK_PORTS' sg docker -c 'docker compose -f labs/hw/compose.yaml run -d --name hw-dut-sink dut /src/labs/hw/dut/start-sink.sh'" >/dev/null || return 1
  local i
  for i in $(seq 1 60); do
    sleep 10
    $SSH "$DUT_SSH" "sg docker -c 'docker logs hw-dut-sink 2>&1' | grep -q 'SINK READY'" && break
    $SSH "$DUT_SSH" "sg docker -c 'docker ps -q --filter name=hw-dut-sink' | grep -q ." ||
      { $SSH "$DUT_SSH" "sg docker -c 'docker logs hw-dut-sink 2>&1' | tail -20"; return 1; }
    [ "$i" = 60 ] && { echo "ERROR: sink VPP not ready" >&2; return 1; }
  done
  dut_c "sh -c 'cd /src/labs/hw/dut && python3 load-scenario.py --scenario 5rules-drop'" | tail -1
}

gen_up() {
  GEN="$GEN" DUT="$DUT" "$HW/gen-image.sh" || return 1
  $SSH "$GEN_SSH" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1
    cd $REPO && GEN=$GEN DUT=$DUT GEN_IDLE=1 GEN_IMAGE='$GEN_IMAGE' TREX_TARGET_MPPS=0 TREX_RATE=100% \
      sg docker -c 'docker compose -f labs/hw/compose.yaml run -d gen'" >/dev/null || return 1
  local i
  for i in $(seq 1 24); do
    sleep 10
    $SSH "$GEN_SSH" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1)
      [ -n \"\$CID\" ] && sg docker -c \"docker logs \$CID\" 2>&1 | grep -q 'TRex left idle'" && return 0
  done
  $SSH "$GEN_SSH" "CID=\$(sg docker -c 'docker ps -aq --filter name=hw-gen' | head -1); sg docker -c \"docker logs \$CID\" 2>&1 | tail -20"
  echo "ERROR: TRex did not come up idle on $GEN" >&2
  return 1
}

down() {
  $SSH "$GEN_SSH" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f'" >/dev/null 2>&1
  $SSH "$DUT_SSH" "sg docker -c 'docker ps -aq --filter name=hw-dut | xargs -r docker stop -t 30 | xargs -r docker rm -f'" >/dev/null 2>&1
}

gen_snap() {
  local ifs="" p
  for p in $TREX_PCI_LIST; do ifs="$ifs $p"; done
  $SSH "$GEN_SSH" "for p in $ifs; do n=\$(ls /sys/bus/pci/devices/\$p/net); ethtool -S \$n | awk '/ tx_packets_phy:/{printf \"%s \", \$2}'; done; date +%s.%N"
}

dut_snap() {
  local e ifs=""
  for e in "${SINK[@]}"; do ifs="$ifs $(cut -d: -f6 <<<"$e")"; done
  $SSH "$DUT_SSH" "for n in $ifs; do ethtool -S \$n | awk '/ (rx_packets_phy|rx_discards_phy|rx_out_of_buffer):/ {gsub(\":\",\"\"); s[\$1]=\$2}
      END {printf \"%s %s %s \", s[\"rx_packets_phy\"], s[\"rx_discards_phy\"], s[\"rx_out_of_buffer\"]}'; done; date +%s.%N"
}

vpp_snap() {
  dut_c "sh -c 'vppctl show fastacl aggregate-counters; vppctl show interface'" |
    awk '/Dropped:/ {d=$2} /^[a-z0-9-]+ +[0-9]+ +(up|down)/ {n=$1} /rx packets/ && n {r[n]=$NF}
         END {printf "%s", d; for (k in r) printf " %s=%s", k, r[k]; printf "\n"}'
  date +%s.%N
}

rig() {
  local d g
  d=$($SSH "$DUT_SSH" 'printf "%s|%s|%s|%s|%s|%s\n" "$(lscpu | sed -n "s/^Model name: *//p")" "$(nproc --all)" "$(uname -r)" \
      "$(ls -d /sys/devices/system/node/node[0-9]* | wc -l)" "$(grep -o "iommu=pt" /proc/cmdline || echo translated)" \
      "$(sudo dmidecode -t memory 2>/dev/null | grep -cE "^\\s+Size: [0-9]+ GB") x $(sudo dmidecode -t memory 2>/dev/null | sed -n "s/^\s*Configured Memory Speed: //p" | sort -u | head -1)"')
  g=$($SSH "$GEN_SSH" 'printf "%s|%s\n" "$(lscpu | sed -n "s/^Model name: *//p")" "$(nproc --all)"')
  DUT_BUFFERS_PER_NUMA="$DUT_BUFFERS_PER_NUMA" python3 - "$d" "$g" "${GEN_IMAGE:-}" "$SINK_PORTS" "$TREX_PCI_LIST" <<'PY' >> "$RESULTS_FILE"
import json, os, sys, time
d, g, image, sink, gen = sys.argv[1].split("|"), sys.argv[2].split("|"), sys.argv[3], sys.argv[4].split(), sys.argv[5].split()
print(json.dumps({"ts": int(time.time()), "bench": "rig", "kind": "platform", "dut_cpu": d[0], "dut_cores": int(d[1]),
                  "dut_kernel": d[2], "dut_numa_nodes": int(d[3]), "dut_iommu": d[4], "dut_memory": d[5], "gen_cpu": g[0], "gen_cores": int(g[1]), "trex_image": image,
                  "vpp_workers": sum(int(e.split(":")[4]) for e in sink), "buffers_per_numa": os.environ.get("DUT_BUFFERS_PER_NUMA", ""),
                  "ports": [{"gen": gen[i], "dut": e.split(":")[3], "queues": int(e.split(":")[4])} for i, e in enumerate(sink)],
                  "verdict": "INFO"}))
PY
}

measure() {
  local name="$1" ports="$2" trial="$3" macs="" p e g1 g2 d1 d2 v1 v2
  for p in ${ports//,/ }; do
    e="${SINK[$p]}"
    macs="$macs,$($SSH "$DUT_SSH" "cat /sys/class/net/$(cut -d: -f6 <<<"$e")/address")"
  done
  gen_c "sh -c 'cd /src/labs/hw/gen/conf && PAIR_DPORT=8000 python3 -W ignore pair_ceiling.py run $ports $SIZE $MULT ${macs#,} $((SECS + 14))'" >/dev/null 2>&1 &
  sleep 10
  dut_c "vppctl clear interfaces" >/dev/null
  g1=$(gen_snap); d1=$(dut_snap); v1=$(vpp_snap)
  sleep "$SECS"
  g2=$(gen_snap); d2=$(dut_snap); v2=$(vpp_snap)
  wait
  python3 - "$name" "$ports" "$trial" "$SIZE" "$g1" "$g2" "$d1" "$d2" "$v1" "$v2" "$SINK_PORTS" "$TREX_PCI_LIST" <<'PY'
import json, sys, time
name, ports, trial, size = sys.argv[1], [int(p) for p in sys.argv[2].split(",")], int(sys.argv[3]), int(sys.argv[4])
def nums(s):
    f = s.split()
    return [float(x) for x in f[:-1]], float(f[-1])
(g1, gt1), (g2, gt2), (d1, dt1), (d2, dt2) = [nums(x) for x in sys.argv[5:9]]
def vpp(s):
    line, t = s.strip().split("\n")
    f = line.split()
    return float(f[0] or 0), {k: float(v) for k, v in (x.split("=") for x in f[1:])}, float(t)
(drop1, rx1, vt1), (drop2, rx2, vt2) = vpp(sys.argv[9]), vpp(sys.argv[10])
sink, gen = sys.argv[11].split(), sys.argv[12].split()
per = []
for p in ports:
    name_p = sink[p].split(":")[3]
    tx = (g2[p] - g1[p]) / (gt2 - gt1) / 1e6
    rx = (d2[3 * p] - d1[3 * p]) / (dt2 - dt1) / 1e6
    lost = ((d2[3 * p + 1] - d1[3 * p + 1]) + (d2[3 * p + 2] - d1[3 * p + 2])) / (dt2 - dt1) / 1e6
    per.append({"port": name_p, "tx_mpps": round(tx, 2), "nic_rx_mpps": round(rx, 2), "nic_lost_mpps": round(lost, 2),
                "vpp_rx_mpps": round((rx2.get(name_p, 0) - rx1.get(name_p, 0)) / (vt2 - vt1) / 1e6, 2)})
tot = lambda k: round(sum(x[k] for x in per), 2)
row = {"ts": int(time.time()), "bench": "platform", "scenario": name, "trial": trial, "frame": size,
       "ports": ",".join(x["port"] for x in per), "tx_mpps": tot("tx_mpps"), "nic_rx_mpps": tot("nic_rx_mpps"),
       "nic_lost_mpps": tot("nic_lost_mpps"), "vpp_rx_mpps": tot("vpp_rx_mpps"),
       "vpp_drop_mpps": round((drop2 - drop1) / (vt2 - vt1) / 1e6, 2), "per_port": per, "verdict": "INFO"}
print(json.dumps(row))
PY
}

rc=0
rig
if dut_up && gen_up; then
  for st in $STAGES; do
    name="${st%%:*}" ports="${st#*:}"
    for t in $(seq 1 "$TRIALS"); do
      row=$(measure "$name" "$ports" "$t") || { rc=1; continue; }
      echo "$row" >> "$RESULTS_FILE"
      echo "$row" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("  %-14s trial %d: sent %6.1f  NIC rx %6.1f  NIC lost %5.1f  VPP rx %6.1f  VPP drop %6.1f Mpps" % (r["scenario"], r["trial"], r["tx_mpps"], r["nic_rx_mpps"], r["nic_lost_mpps"], r["vpp_rx_mpps"], r["vpp_drop_mpps"]))'
    done
  done
else
  rc=1
fi
[ "${PLATFORM_KEEP:-0}" = 1 ] || down
echo; [ "$rc" = 0 ] && echo "PLATFORM CEILING DONE" || echo "PLATFORM CEILING FAILED"
exit $rc
