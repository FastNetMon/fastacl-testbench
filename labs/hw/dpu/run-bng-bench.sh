#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail
export LC_ALL=C

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

NAT_SESSIONS="${BNG_NAT_SESSIONS:-200000}"
WARM_SEC="${BNG_WARM_SEC:-10}"
CONFORM_BPS=1000000000
CONFORM_BURST=262144

bng_setup() {
  local filter="$1" nat="$2"
  cat <<EOF
set interface state p0 up
set interface state p1 up
set interface promiscuous on p1
set interface mac address p1 ${DUT_LEFT_MAC}
set interface ip address p1 10.10.1.1/24
set interface ip address p0 192.0.2.1/24
set ip neighbor p0 192.0.2.2 ${RECEIVER_MAC}
ip route add 0.0.0.0/0 via 192.0.2.2 p0
EOF
  if [ "$nat" = 1 ]; then
    cat <<EOF
nat44 plugin enable sessions ${NAT_SESSIONS}
set interface nat44 out p0 output-feature
nat44 add address 203.0.113.0 - 203.0.113.255
EOF
  fi
  [ "$filter" = 1 ] && echo "set interface fastacl p1"
  return 0
}

tx_fwd() { vpp show interface p0 | awk '/tx packets/ {print $NF; exit}'; }

load_subscribers() {
  $SSH "$DPU" "docker exec bf3-vpp python3 /src/labs/hw/dut/load-subscribers.py $1 $2 $3" 2>&1 | tail -1
}

measure_fwd() {
  local r0 r1 f0 f1 p0 p1 tr0 tr1 tp0 tp1
  vpp clear runtime >/dev/null
  p0=$(nic_phy); tp0=$(date +%s.%N); r0=$(rx_good); f0=$(tx_fwd); tr0=$(date +%s.%N)
  sleep "$SAMPLE_SEC"
  r1=$(rx_good); f1=$(tx_fwd); tr1=$(date +%s.%N); p1=$(nic_phy); tp1=$(date +%s.%N)
  local ticks
  ticks=$(vpp show runtime | awk '
    $4 ~ /^[0-9]+$/ && $4 > 0 && $6 ~ /^[0-9.e+]+$/ {
      c = $4 * $6; total += c
      if ($1 ~ /^fastacl-filter/) f += c
      if ($1 ~ /^nat/) n += c
      if ($1 ~ /^ip4-input/) pk += $4
      if ($1 ~ /^(rdma|dpdk)-input/) w++ }
    END {if (pk) printf "%s %s %.1f %d", (f ? sprintf("%.1f", f / pk) : "-"), (n ? sprintf("%.1f", n / pk) : "-"), total / pk, w
         else printf "- - - %d", w}')
  awk -v r0="${r0:-0}" -v r1="${r1:-0}" -v f0="${f0:-0}" -v f1="${f1:-0}" -v s="$tr0" -v e="$tr1" \
      -v pa="${p0:-0}" -v pb="${p1:-0}" -v ps="$tp0" -v pe="$tp1" -v t="$ticks" \
    'BEGIN{rx = (r1 - r0) / (e - s); fwd = (f1 - f0) / (e - s); phy = (pb - pa) / (pe - ps)
           lost = (phy > 0) ? sprintf("%.2f", (phy > rx ? (phy - rx) * 100 / phy : 0)) : "-"
           printf "%.2f %.2f %s %s", fwd / 1e6, rx / 1e6, lost, t}'
}

measure_trials() {
  local i out=""
  for i in $(seq 1 "$TRIALS"); do
    out+="$(measure_fwd)"$'\n'
  done
  printf '%s' "$out" | sort -n -k1,1 | awk '
    {m[NR] = $0; f[NR] = $1}
    END {k = int((NR + 1) / 2); printf "%s %s %s", m[k], f[1], f[NR]}'
}

record() {
  local scenario="$1" pipeline="$2" subs="$3" ports="$4" frame="$5" rate="$6" expected="$7" result="$8"
  local fwd rx lost ftick ntick ttick workers lo hi sessions=""
  read -r fwd rx lost ftick ntick ttick workers lo hi <<<"$result"
  [ "$lost" = - ] && lost=""; [ "$ftick" = - ] && ftick=""; [ "$ntick" = - ] && ntick=""; [ "$ttick" = - ] && ttick=""
  [ "$pipeline" = nat ] || [ "$pipeline" = bng ] && sessions=$((subs * ports))
  echo "  $scenario $frame: forwarded $fwd Mpps (received $rx, range $lo-$hi), NIC loss ${lost:--}%," \
    "filter ${ftick:--} / NAT ${ntick:--} / total ${ttick:--} ticks/pkt, $workers workers receiving${expected:+, expected $expected Mpps}"
  emit bench=bng scenario="$scenario" pipeline="$pipeline" subscribers="$subs" ports="$ports" \
    sessions="$sessions" frame="$frame" rate_bps="$rate" expected_mpps="$expected" \
    dut_mpps="$fwd" rx_mpps="$rx" mpps_min="$lo" mpps_max="$hi" trials="$TRIALS" \
    nic_lost_pct="${lost:-}" filter_ticks="${ftick:-}" nat_ticks="${ntick:-}" total_ticks="${ttick:-}" rx_workers="$workers" rss="${RDMA_RSS:-default}" verdict=INFO
}

run_point() {
  local scenario="$1" pipeline="$2" subs="$3" ports="$4" frame="$5" rate="${6:-}" expected="${7:-}"
  local attack=bng size=64
  [ "$frame" = imix ] && attack=bng-imix
  say "=== $scenario: $pipeline, $subs subscribers x $ports ports, $frame ==="
  if [ "$CUR_GEN" != "$attack" ]; then
    start_gen "$size" "$attack" || { emit bench=load scenario="generator $scenario" verdict=FAIL; rc=1; return; }
    CUR_GEN="$attack"
  fi
  gen_param bng-subs "$subs"; gen_param bng-ports "$ports"
  switch_attack "$attack"
  sleep "$WARM_SEC"
  record "$scenario" "$pipeline" "$subs" "$ports" "$frame" "$rate" "$expected" "$(measure_trials)"
}

start_pipeline() {
  local pipeline="$1" filter=0 nat=0
  case "$pipeline" in
    policer) filter=1 ;;
    nat) nat=1 ;;
    bng) filter=1; nat=1 ;;
  esac
  vpp_stop
  bringup_dut "$(bng_setup "$filter" "$nat")" || { emit bench=load scenario="bring-up $pipeline" verdict=FAIL; return 1; }
}

vpp_stop() { $SSH "$DPU" "docker rm -f bf3-vpp >/dev/null 2>&1" || true; }

trap teardown EXIT
rc=0
CUR_GEN=""

start_pipeline routed || exit 1
rig
run_point "routed" routed 10000 10 64
run_point "routed" routed 10000 10 imix

start_pipeline policer || exit 1
say "$(load_subscribers 10000 $CONFORM_BPS $CONFORM_BURST)"
run_point "policer" policer 10000 10 64
run_point "policer" policer 10000 10 imix

start_pipeline nat || exit 1
run_point "nat" nat 10000 10 64
run_point "nat" nat 10000 10 imix

start_pipeline bng || exit 1
say "$(load_subscribers 10000 $CONFORM_BPS $CONFORM_BURST)"
run_point "bng" bng 10000 10 64
run_point "bng" bng 10000 10 imix
run_point "bng sessions" bng 10000 1 64

start_pipeline bng || exit 1
say "$(load_subscribers 100000 $CONFORM_BPS $CONFORM_BURST)"
run_point "bng sessions" bng 100000 10 64

for rate in 10000000 20000000; do
  start_pipeline bng || exit 1
  say "$(load_subscribers 100 $rate 16384)"
  run_point "policer accuracy" bng 100 1 64 "$rate" "$(awk -v r="$rate" 'BEGIN{printf "%.2f", 100 * r / (50 * 8) / 1e6}')"
done

start_pipeline routed || exit 1
run_point "rss default" routed 1 1000 64
RDMA_RSS=ipv4-udp
start_pipeline routed || exit 1
run_point "rss ipv4-udp" routed 1 1000 64
run_point "rss ipv4-udp" routed 10000 10 64
RDMA_RSS=

echo; [ "$rc" = 0 ] && echo "BNG BENCH DONE" || echo "BNG BENCH FAILED"
exit $rc
