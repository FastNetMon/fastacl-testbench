#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -euo pipefail

cd "$(dirname "$0")/.."

files=$(git ls-files --cached --others --exclude-standard)

echo "==> shell syntax"
for f in $(printf '%s\n' $files | grep -E '\.sh$'); do bash -n "$f"; done

echo "==> python syntax"
printf '%s\n' $files | grep -E '\.py$' | xargs python3 -m py_compile

echo "==> no lab secrets in the tree"
pattern='BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|\.ts\.net|192\.168\.[0-9]+\.[0-9]+|tskey-'
if printf '%s\n' $files | grep -vE '^(scripts/lint\.sh|labs/hw/report\.py|labs/hw/lab\.env)$' \
    | xargs grep -nE "$pattern" 2>/dev/null; then
  echo "lint: lab addresses or keys found in tracked files (they belong in the LAB_ENV secret)"
  exit 1
fi
echo "lint: clean"
