#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${LAB_ENV_CONTENT:?LAB_ENV secret is empty}"
: "${LAB_SSH_KEY:?LAB_SSH_KEY secret is empty}"
: "${GH_TOKEN:?FASTACL_RELEASE_TOKEN secret is empty}"

umask 077
printf '%s\n' "$LAB_ENV_CONTENT" > "$ROOT/labs/hw/lab.env"
install -d -m 700 ~/.ssh
printf '%s\n' "$LAB_SSH_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
printf 'Host *\n  IdentityFile ~/.ssh/id_ed25519\n  StrictHostKeyChecking accept-new\n  BatchMode yes\n  ServerAliveInterval 15\n' > ~/.ssh/config
chmod 600 ~/.ssh/config

mkdir -p "$ROOT/labs/hw/license"
if [ -n "${FASTACL_LAB_LICENSE_JSON:-}" ] && [ -n "${FASTACL_LAB_LICENSE_SIG:-}" ]; then
  printf '%s' "$FASTACL_LAB_LICENSE_JSON" > "$ROOT/labs/hw/license/fastacl-license.json"
  printf '%s' "$FASTACL_LAB_LICENSE_SIG" > "$ROOT/labs/hw/license/fastacl-license.json.sig"
  echo "lab licence: from secrets"
else
  echo "lab licence: none in secrets, the bundle's evaluation licence will be used"
fi
umask 022
