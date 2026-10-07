#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUITE="${1:-gate}"
PROFILE="${PROFILE:-server1}"

set -a
. "$SCRIPT_DIR/profiles/$PROFILE.env"
set +a
export RESULTS_FILE="${RESULTS_FILE:-$SCRIPT_DIR/../../results/run.jsonl}"
mkdir -p "$(dirname "$RESULTS_FILE")"

bench() {
  echo "::group::bench.sh $*"
  "$SCRIPT_DIR/bench.sh" "$@"
  echo "bench.sh $1 exit=$?"
  echo "::endgroup::"
}

gate() {
  bench rig
  bench oneport --attack "$ONEPORT_ATTACK" --scenarios 5rules-drop --floor "$DROP_FLOOR" \
    --max-nic-lost "$DROP_MAX_NIC_LOST" --max-cyc-drop "$DROP_MAX_CYC"
  bench oneport --attack "${FWD_ATTACK:-fwd-flood-32}" --scenarios 0rules --offered "$FWD_OFFERED" \
    --floor "$FWD_FLOOR" --max-nic-lost "$DROP_MAX_NIC_LOST" --max-cyc-pass "$FWD_MAX_CYC"
  bench oneport --attack "$ONEPORT_ATTACK" --scenarios country-set-drop --floor "$SETS_FLOOR" \
    --max-cyc-drop "$SETS_MAX_CYC_DROP" --max-cyc-pass "$SETS_MAX_CYC_PASS"
  bench sets-tuples --scenario country-set-drop --max-tuples "$SETS_MAX_TUPLES"
  bench flows --flows "$FLOWS_V4" --absorb "$FLOWS_ABSORB" --max-cyc "$FLOWS_MAX_CYC"
  bench flows --attack cold-scan-scatter --flows "$FLOWS_V4" --absorb "$FLOWS_ABSORB" \
    --max-cyc "$FLOWS_MAX_CYC"
  bench flows --attack cold-scan-imix --flows "$IMIX_FLOWS" --absorb "$IMIX_ABSORB" \
    --max-cyc "$IMIX_MAX_CYC"
  bench flows --scenario 1m-rules-drop-ip6 --attack ip6-cold-scan --flows "$FLOWS_V6" \
    --absorb "$FLOWS_ABSORB" --max-cyc "$FLOWS_V6_MAX_CYC"
  bench psample
}

stage_ceiling() { bench ceiling --attack "$ONEPORT_ATTACK"; }
stage_rules() {
  bench survey --sweep rules --attacks "$ONEPORT_ATTACK" --flows 0 --nrules "$FULL_NRULES_SWEEP"
}
stage_attacks() { bench survey --sweep attacks --scenarios "5rules-drop 1m-rules-drop"; }
stage_scenarios() {
  bench survey --sweep scenarios --scenarios "$FULL_SCENARIOS" \
    --attacks "fixed-flood-31 cold-scan multivector"
}
stage_flows() {
  bench survey --sweep flows --scenarios 1m-rules-drop --attacks cold-scan --flows "$FULL_FLOWS_SWEEP"
  bench survey --sweep flows --scenarios 1m-rules-drop-ip6 --attacks ip6-cold-scan \
    --flows "$FULL_FLOWS_SWEEP"
}
stage_frames() { bench frames --sizes "$FULL_FRAME_SIZES"; }
stage_twoport() {
  bench oneport --ports 2 --attack "$ONEPORT_ATTACK" --scenarios "5rules-drop 1m-rules-drop" \
    --floor 0 --max-nic-lost 0 --max-cyc-drop ""
}

FULL_STAGES="${FULL_STAGES:-gate ceiling rules attacks scenarios flows frames twoport}"

full() {
  local s started=""
  for s in $FULL_STAGES; do
    [ -z "${FROM:-}" ] || [ "$s" = "$FROM" ] && started=1
    [ -n "$started" ] || continue
    if [ "$s" = gate ]; then gate; else "stage_$s"; fi
  done
}

dpu() {
  local bench="${1:-run-dpu-bench.sh}" sizes="$GATE_FRAME_SIZES" rc=0
  [ "$SUITE" = full ] && sizes="$FULL_FRAME_SIZES"
  if [ -n "${RESTORE_BF_MODE:-}" ]; then
    trap '"$SCRIPT_DIR/bf-mode.sh" "$RESTORE_BF_MODE"' EXIT
  fi
  "$SCRIPT_DIR/bf-mode.sh" "$DUT_BF_MODE" ||
    { printf '{"ts": %s, "dut": "%s", "bench": "load", "scenario": "bf-mode %s", "verdict": "FAIL"}\n' \
        "$(date +%s)" "$PROFILE" "$DUT_BF_MODE" >> "$RESULTS_FILE"; return 1; }
  "$SCRIPT_DIR/sync-hosts.sh" ||
    { printf '{"ts": %s, "dut": "%s", "bench": "load", "scenario": "sync", "verdict": "FAIL"}\n' \
        "$(date +%s)" "$PROFILE" >> "$RESULTS_FILE"; return 1; }
  DPU_FRAME_SIZES="$sizes" DPU_TRIALS="${DPU_TRIALS:-$([ "$SUITE" = full ] && echo 3 || echo 1)}" \
    "$SCRIPT_DIR/dpu/$bench" || rc=$?
  echo "$bench exit=$rc"
  return $rc
}

case "$SUITE:${DUT_KIND:-host}" in
  gate:dpu|full:dpu) dpu ;;
  bng:dpu) export DUT_DRIVER="${DUT_DRIVER_BNG:-rdma}" DPU_TRIALS="${DPU_TRIALS:-3}"; dpu run-bng-bench.sh ;;
  gate:host) gate ;;
  full:host) full ;;
  none:*) ;;
  *) echo "usage: suite.sh gate|full|bng|none   (PROFILE=server1|epyc-sp5|epyc-cx8|bluefield3|alice|bob, FROM=<stage> to resume)" >&2
     exit 2 ;;
esac
