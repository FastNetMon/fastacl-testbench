#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)
set -uo pipefail
export LC_ALL=C
HW="$(cd "$(dirname "$0")" && pwd)"
. "$HW/vars.sh" >/dev/null 2>&1
RUN_PID="${1:?usage: nic-temp-guard.sh <run.sh pid>}"
RESULTS_FILE="${RESULTS_FILE:-$HW/../../results/run.jsonl}"
STOP_FILE="$(dirname "$RESULTS_FILE")/thermal-stop"
LIMIT="${NIC_TEMP_LIMIT:-95}"
POLL="${NIC_TEMP_POLL:-30}"
LOG_EVERY="${NIC_TEMP_LOG_EVERY:-300}"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"

hosts=("$DUT_HOST" "$SENDER_HOST")
[ "${DUT_KIND:-host}" = dpu ] && hosts+=("${LAB_HOST_bluefield3:-}")
mapfile -t hosts < <(printf '%s\n' "${hosts[@]}" | awk 'NF && !seen[$0]++')
declare -A MAX DMESG0

probe() {
  $SSH "$LAB_SSH_USER@$1" 't=0
    for f in /sys/class/hwmon/hwmon*; do
      case "$(cat $f/name 2>/dev/null)" in mlx5*)
        for i in $f/temp*_input; do v=$(( $(cat $i) / 1000 )); [ $v -gt $t ] && t=$v; done;; esac
    done
    echo "$t $(sudo -n dmesg 2>/dev/null | wc -l)"' 2>/dev/null
}

dmesg_hits() {
  $SSH "$LAB_SSH_USER@$1" "sudo -n dmesg 2>/dev/null | tail -n +$(( $2 + 1 )) |
    grep -iE 'mlx5.*(temperat|thermal|overheat)|(temperat|thermal).*mlx5' | tail -3" 2>/dev/null
}

emit_max() {
  local h
  for h in "${hosts[@]}"; do
    printf '{"ts": %s, "bench": "thermal", "scenario": "%s", "max_temp_c": %s, "limit_c": %s, "verdict": "INFO"}\n' \
      "$(date +%s)" "${h%%.*}" "${MAX[$h]:-0}" "$LIMIT" >> "$RESULTS_FILE"
  done
}

trip() {
  local h="$1" why="$2" x
  echo ">> nic-temp-guard: STOP — ${h%%.*}: $why" >&2
  echo "${h%%.*}: $why" > "$STOP_FILE"
  printf '{"ts": %s, "bench": "load", "scenario": "nic temperature %s", "verdict": "FAIL", "detail": "%s"}\n' \
    "$(date +%s)" "${h%%.*}" "$why" >> "$RESULTS_FILE"
  for x in "${hosts[@]}"; do
    $SSH "$LAB_SSH_USER@$x" "sg docker -c 'docker ps -aq --filter name=hw- --filter name=bf3-vpp | xargs -r docker rm -f'" >/dev/null 2>&1 &
  done
  wait
  local sid
  sid=$(ps -o sid= -p "$RUN_PID" | tr -d ' ')
  [ -n "$sid" ] && pkill -TERM -s "$sid" -f 'labs/hw/(suite|bench|pair-ceiling)\.sh|run-(dpu|bng)-bench\.sh'
  emit_max
  exit 0
}

trap 'emit_max; exit 0' TERM INT
rm -f "$STOP_FILE"
for h in "${hosts[@]}"; do
  read -r t n <<<"$(probe "$h")"
  MAX[$h]="${t:-0}"; DMESG0[$h]="${n:-0}"
done
echo ">> nic-temp-guard: watching ${hosts[*]%%.*} every ${POLL}s, limit ${LIMIT} C"
last_log=0
while kill -0 "$RUN_PID" 2>/dev/null; do
  line=""
  for h in "${hosts[@]}"; do
    read -r t n <<<"$(probe "$h")"
    [ -n "${t:-}" ] || continue
    [ "$t" -gt "${MAX[$h]:-0}" ] && MAX[$h]="$t"
    line="$line ${h%%.*}=${t}C"
    [ "$t" -ge "$LIMIT" ] && trip "$h" "NIC ASIC at ${t} C (limit ${LIMIT} C)"
    if [ "${n:-0}" -gt "${DMESG0[$h]}" ]; then
      hit=$(dmesg_hits "$h" "${DMESG0[$h]}")
      [ -n "$hit" ] && trip "$h" "kernel: $(echo "$hit" | tail -1 | tr -d '"\\')"
      DMESG0[$h]="$n"
    fi
  done
  now=$(date +%s)
  if [ $((now - last_log)) -ge "$LOG_EVERY" ]; then
    echo ">> nic-temp-guard:$line"; last_log=$now
  fi
  sleep "$POLL" & wait $!
done
emit_max
