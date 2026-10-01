#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -euo pipefail

HW="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HW/../.." && pwd)"
. "$HW/vars.sh" >/dev/null 2>&1

hosts=("$@")
if [ ${#hosts[@]} -eq 0 ]; then
  if [ "${DUT_KIND:-host}" = dpu ]; then hosts=("$LAB_HOST_bluefield3"); else hosts=("$DUT_HOST"); fi
  hosts+=("$SENDER_HOST")
fi

for h in "${hosts[@]}"; do
  echo ">> sync ${ROOT##*/} -> ${h%%.*}:~/${HOST_REPO:-fastacl-testbench}"
  rsync -az --delete -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=no" \
    --exclude .git --exclude results --exclude out --exclude reports --exclude __pycache__ \
    "$ROOT"/ "$LAB_SSH_USER@$h:~/${HOST_REPO:-fastacl-testbench}/"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$LAB_SSH_USER@$h" "sync"
done
