#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)
set -uo pipefail
export LC_ALL=C
HW="$(cd "$(dirname "$0")" && pwd)"
. "$HW/vars.sh" >/dev/null 2>&1
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15"
RESULTS_FILE="${RESULTS_FILE:-$HW/../../results/run.jsonl}"
SIZES="${PAIR_SIZES:-64 128 256 512 1518}"
SECS="${PAIR_SECS:-10}"
A="$DUT" B="$GEN"
HOST_a="$DUT_HOST" HOST_b="$SENDER_HOST"

host_of() { [ "$1" = "$A" ] && echo "$HOST_a" || echo "$HOST_b"; }

port_mac() {
  local pci="0000:01:00.1"
  [ "$2" = 1 ] && pci="0000:01:00.0"
  $SSH "$LAB_SSH_USER@$(host_of "$1")" "cat /sys/bus/pci/devices/$pci/net/*/address"
}

gen_up() {
  local me="$1" peer="$2" h
  h="$(host_of "$me")"
  GEN="$me" DUT="$peer" "$HW/gen-image.sh" || return 1
  $SSH "$LAB_SSH_USER@$h" "cd ~/${HOST_REPO:-fastacl-testbench} &&
    sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1
    GEN=$me DUT=$peer GEN_IDLE=1 GEN_IMAGE='${GEN_IMAGE:-hw-gen}' TREX_TARGET_MPPS=0 TREX_RATE=100% \
      sg docker -c 'docker compose -f labs/hw/compose.yaml run -d gen'" >/dev/null 2>&1
  local i
  for i in $(seq 1 18); do
    sleep 10
    $SSH "$LAB_SSH_USER@$h" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1)
      [ -n \"\$CID\" ] && sg docker -c \"docker logs \$CID\" 2>&1 | grep -q 'TRex left idle'" && return 0
  done
  echo "ERROR: TRex did not come up idle on $me" >&2
  return 1
}

gen_down() {
  $SSH "$LAB_SSH_USER@$(host_of "$1")" \
    "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f'" >/dev/null 2>&1
}

phy() {
  $SSH "$LAB_SSH_USER@$(host_of "$1")" 'for d in /sys/bus/pci/devices/0000:01:00.1/net/* /sys/bus/pci/devices/0000:01:00.0/net/*; do n=${d##*/}
      ethtool -S $n | awk -v n=$n "/ (tx_packets_phy|rx_packets_phy|rx_discards_phy|rx_out_of_buffer):/ {gsub(\":\",\"\"); s[\$1]=\$2}
        END {printf \"%s %s %s %s \", s[\"tx_packets_phy\"], s[\"rx_packets_phy\"], s[\"rx_discards_phy\"] + s[\"rx_out_of_buffer\"], n}"
    done; date +%s.%N'
}

measure() {
  local tx="$1" rx="$2" ports="$3" size="$4" macs="" p a1 a2 b1 b2
  for p in ${ports//,/ }; do macs="$macs,$(port_mac "$rx" "$p")"; done
  $SSH "$LAB_SSH_USER@$(host_of "$tx")" "CID=\$(sg docker -c 'docker ps -q --filter name=hw-gen' | head -1)
    sg docker -c \"docker exec \$CID sh -c 'cd /src/labs/hw/gen/conf && python3 -W ignore pair_ceiling.py run $ports $size 700mpps ${macs#,} $((SECS + 12))'\"" \
    >/dev/null 2>&1 &
  sleep 8
  a1=$(phy "$tx"); b1=$(phy "$rx"); sleep "$SECS"; a2=$(phy "$tx"); b2=$(phy "$rx")
  wait
  python3 - "$a1" "$a2" "$b1" "$b2" "$tx" "$rx" "$ports" "$size" <<'PY'
import json, sys, time
def parse(s):
    f = s.split()
    return [tuple(map(float, f[i:i + 3])) for i in range(0, len(f) - 1, 4)], float(f[-1])
(a1, t1), (a2, t2), (b1, u1), (b2, u2) = [parse(x) for x in sys.argv[1:5]]
tx, rx, ports, size = sys.argv[5], sys.argv[6], sys.argv[7], int(sys.argv[8])
txm = sum(a2[i][0] - a1[i][0] for i in range(2)) / (t2 - t1) / 1e6
rxm = sum(b2[i][1] - b1[i][1] for i in range(2)) / (u2 - u1) / 1e6
drop = sum(b2[i][2] - b1[i][2] for i in range(2)) / (u2 - u1) / 1e6
l1 = (size + 20) * 8 / 1e3
print(json.dumps({"ts": int(time.time()), "bench": "pair", "scenario": f"{tx} -> {rx}",
                  "ports": len(ports.split(",")), "frame": size, "tx_mpps": round(txm, 2),
                  "tx_gbps": round(txm * l1, 1), "rx_mpps": round(rxm, 2),
                  "rx_dropped_mpps": round(drop, 2), "rx_delivered_mpps": round(rxm - drop, 2),
                  "verdict": "INFO"}))
PY
}

rig() {
  local info
  info=$($SSH "$LAB_SSH_USER@$HOST_a" 'n=$(ls /sys/bus/pci/devices/0000:01:00.1/net)
    printf "%s|%s|%s|%s|%s|%s|%s\n" "$(lscpu | sed -n "s/^Model name: *//p")" "$(nproc --all)" "$(uname -r)" \
      "$(lspci -s 01:00.0 | cut -d: -f3- | sed "s/^ *//")" "$(ethtool -i $n | sed -n "s/^firmware-version: //p")" \
      "$(($(cat /sys/class/net/$n/speed) / 1000)) Gbps" \
      "$(sudo lspci -s 01:00.0 -vv | sed -n "s/.*LnkSta:\s*//p" | head -1)"')
  IFS='|' read -r cpu cores kernel nic fw link pcie <<<"$info"
  python3 - "$cpu" "$cores" "$kernel" "$nic" "$fw" "$link" "$pcie" "${GEN_IMAGE:-}" <<'PY' >> "$RESULTS_FILE"
import json, sys, time
cpu, cores, kernel, nic, fw, link, pcie, image = sys.argv[1:]
print(json.dumps({"ts": int(time.time()), "bench": "rig", "kind": "pair", "host_cpu": cpu, "host_cores": int(cores),
                  "host_kernel": kernel, "host_nic": nic, "nic_fw": fw, "link_speed": link, "pcie_link": pcie,
                  "trex_version": "v3.08 (source)", "trex_image": image, "trex_cores": 30, "verdict": "INFO"}))
PY
}

rc=0
rig
gen_up "$A" "$B" && gen_up "$B" "$A" || rc=1
if [ "$rc" = 0 ]; then
  for dir in "$B $A" "$A $B"; do
    set -- $dir
    for size in $SIZES; do
      for ports in 0 0,1; do
        row=$(measure "$1" "$2" "$ports" "$size")
        echo "$row" >> "$RESULTS_FILE"
        echo "$row" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("  %s, %s port(s), %s B: sent %s Mpps (%s Gbps), received %s Mpps, dropped by receiver %s Mpps" % tuple(r[k] for k in ("scenario", "ports", "frame", "tx_mpps", "tx_gbps", "rx_mpps", "rx_dropped_mpps")))'
      done
    done
  done
fi
gen_down "$A"; gen_down "$B"
echo; [ "$rc" = 0 ] && echo "PAIR CEILING DONE" || echo "PAIR CEILING FAILED"
exit $rc
