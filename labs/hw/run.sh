#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -uo pipefail
export LC_ALL=C

HW="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HW/../.." && pwd)"
PROFILE="${1:?usage: run.sh <server1|epyc-sp5|bluefield3> [gate|full]}"
SUITE="${2:-gate}"
export PROFILE SUITE DUT_PROFILE="$PROFILE" HOST_REPO="${HOST_REPO:-fastacl-testbench}"

set -a
. "$HW/profiles/$PROFILE.env"
set +a
[ "${CALIBRATE_INPUT:-false}" = true ] && export CALIBRATE=1
. "$HW/vars.sh" >/dev/null 2>&1
export DUT_SEL="$DUT"
export RELEASE_TAG="${RELEASE_TAG:-latest-main}"
export TESTBENCH_SHA="${TESTBENCH_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet HEAD 2>/dev/null || echo -dirty)}"
[ -n "${GITHUB_RUN_ID:-}" ] && export RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
VPP="${VPP:-2510}"
PUBLISH="${PUBLISH:-0}"
[ "$SUITE" = full ] && PUBLISH="${PUBLISH_FULL:-1}"
export RESULTS_FILE="$ROOT/results/run.jsonl"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15"
GEN_SSH="$LAB_SSH_USER@$SENDER_HOST"

say() { echo; echo "== run.sh: $*"; }
fail_row() {
  printf '{"ts": %s, "dut": "%s", "bench": "load", "scenario": "%s", "verdict": "FAIL"}\n' \
    "$(date +%s)" "$PROFILE" "$1" >> "$RESULTS_FILE"
}

fetch_bundle() {
  local ref="$RELEASE_TAG" asset
  [ "$ref" = latest-main ] && ref=main
  asset="fastacl-${ref}-vpp${VPP}${BUNDLE_SUFFIX:-}.tar.gz"
  say "bundle $asset from ${FASTACL_REPO:-FastNetMon/fastacl} release $RELEASE_TAG"
  rm -rf "$ROOT/bundle" && mkdir -p "$ROOT/bundle"
  gh release download "$RELEASE_TAG" -R "${FASTACL_REPO:-FastNetMon/fastacl}" -p "$asset" \
    -D "$ROOT/bundle" --clobber || return 1
  tar -xzf "$ROOT/bundle/$asset" -C "$ROOT/bundle" && rm -f "$ROOT/bundle/$asset"
  ls "$ROOT"/bundle/debs/fastacl-plugin_*.deb
}

start_gen() {
  $SSH "$GEN_SSH" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1
    cd ~/${HOST_REPO} && GEN='$GEN' DUT='$DUT' TREX_TARGET_MPPS='$TREX_TARGET_MPPS' \
      sg docker -c 'docker compose -f labs/hw/compose.yaml run -d gen'" >/dev/null
  sleep 60
}

host_run() {
  say "sync"; "$HW/sync-hosts.sh" || { fail_row "sync"; return 1; }
  say "DUT image"
  $SSH "$LAB_SSH_USER@$DUT_HOST" "sg docker -c 'bash ~/${HOST_REPO}/labs/hw/dut-image.sh'" ||
    { fail_row "dut image"; return 1; }
  local try
  for try in 1 2; do
    say "DUT bring-up (attempt $try)"
    "$HW/bringup-guarded.sh" --watch-secs 600 && break
    [ "$try" = 2 ] && { fail_row "dut bring-up"; return 1; }
  done
  say "generator"; start_gen || { fail_row "generator"; return 1; }
  say "suite $SUITE"; "$HW/suite.sh" "$SUITE"
}

report() {
  local name out gate="" rc=0
  name="$(date -u +%Y-%m-%d_%H%M)_${PROFILE}_${SUITE}"
  out="$ROOT/out/$name"
  say "report $name"
  [ "${CALIBRATE:-0}" = 1 ] && gate="--no-gate"
  python3 "$HW/report.py" "$RESULTS_FILE" --out-dir "$out" $gate || rc=$?
  cp "$RESULTS_FILE" "$out/" 2>/dev/null || true
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$out/report.md" >> "$GITHUB_STEP_SUMMARY"; fi
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "dir=$out" >> "$GITHUB_OUTPUT"; echo "name=$name" >> "$GITHUB_OUTPUT"; fi
  [ "$PUBLISH" = 1 ] && "$HW/publish-results.sh" "$out" "$name"
  return $rc
}

rm -f "$RESULTS_FILE"; mkdir -p "$(dirname "$RESULTS_FILE")"
if fetch_bundle; then
  if [ "${DUT_KIND:-host}" = dpu ]; then say "suite $SUITE"; "$HW/suite.sh" "$SUITE"; else host_run; fi
else
  fail_row "release bundle"
fi
report; rc=$?
if [ "${DUT_KIND:-host}" != dpu ] && [ "${TEARDOWN:-1}" = 1 ]; then
  say "teardown"; "$HW/teardown.sh"
fi
exit $rc
