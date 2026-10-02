#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail
export LC_ALL=C

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

FRAMES="${DPU_FRAME_SIZES:-64 imix 1500}"
FLOOR_64="${FLOOR_64:-45}"; FLOOR_imix="${FLOOR_IMIX:-28}"; FLOOR_1500="${FLOOR_1500:-7}"

measure_drop_mpps() {
  vpp fastacl rule del all >/dev/null; vpp fastacl rule add order 10 proto 17 action drop >/dev/null
  sleep 4
  local g0 g1 t0 t1
  vpp clear runtime >/dev/null
  local p0 p1 tp0 tp1
  p0=$(nic_phy); tp0=$(date +%s.%N); g0=$(rx_good); t0=$(date +%s.%N)
  sleep "$SAMPLE_SEC"
  g1=$(rx_good); t1=$(date +%s.%N); p1=$(nic_phy); tp1=$(date +%s.%N)
  local cyc
  cyc=$(vpp show runtime | awk '$1 ~ /^fastacl-filter/ {v += $4; c += $4 * $6} END {if (v) printf "%.1f", c / v}')
  awk -v a="${g0:-0}" -v b="${g1:-0}" -v s="$t0" -v e="$t1" -v c="${cyc:--}" \
      -v pa="${p0:-0}" -v pb="${p1:-0}" -v ps="$tp0" -v pe="$tp1" \
    'BEGIN{good = (b - a) / (e - s); phy = (pb - pa) / (pe - ps)
           lost = (phy > 0) ? sprintf("%.2f", (phy > good ? (phy - good) * 100 / phy : 0)) : "-"
           printf "%.1f %s %s", good / 1e6, c, lost}'
}

measure_trials() {
  local i out=""
  for i in $(seq 1 "$TRIALS"); do
    out+="$(measure_drop_mpps)"$'\n'
  done
  printf '%s' "$out" | sort -n -k1,1 | awk '
    {m[NR] = $1; c[NR] = $2; l[NR] = $3}
    END {k = int((NR + 1) / 2); printf "%s %s %s %s %s", m[k], c[k], m[1], m[NR], l[k]}'
}

record() {
  local frame="$1" attack="$2" mpps cyc lo hi lost floor verdict=INFO
  read -r mpps cyc lo hi lost <<<"$3"
  [ "$cyc" = - ] && cyc=""; [ "$lost" = - ] && lost=""
  floor=$(eval "echo \${FLOOR_$frame:-}")
  if [ -n "$floor" ] && [ "$CALIBRATE" != 1 ]; then
    if awk -v m="$mpps" -v f="$floor" 'BEGIN{exit !(m >= f)}'; then verdict=PASS; else verdict=FAIL; rc=1; fi
  fi
  echo "  $frame drop: $mpps Mpps (median of $TRIALS, range ${lo:-$mpps}-${hi:-$mpps}), ${cyc:--} ticks/pkt, NIC loss ${lost:--}% (floor ${floor:--}) $verdict"
  emit bench=dpu scenario="udp drop ${frame}" frame="$frame" attack="$attack" rules=1 \
    dut_mpps="$mpps" mpps_min="${lo:-$mpps}" mpps_max="${hi:-$mpps}" trials="$TRIALS" \
    cyc_pkt="${cyc:-}" nic_lost_pct="${lost:-}" floor="${floor:-}" verdict="$verdict"
}


trap teardown EXIT

rc=0
if ! bringup_dut "$(sed -e 's|__IF_LEFT__|p0|g' -e 's|__IF_RIGHT__|p1|g' "$HW/dut/conf/setup.vpp")"; then
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
