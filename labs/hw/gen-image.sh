#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)
set -euo pipefail
HW="$(cd "$(dirname "$0")" && pwd)"
. "$HW/vars.sh" >/dev/null 2>&1
[ -n "${GEN_IMAGE:-}" ] || exit 0
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=15"

fetch_local() {
  docker image inspect "$GEN_IMAGE" >/dev/null 2>&1 && return 0
  local cfg token
  cfg="$(mktemp -d)"
  token="${GHCR_TOKEN:-$(gh auth token 2>/dev/null || true)}"
  [ -n "$token" ] || { echo "ERROR: no GHCR_TOKEN and no gh login to pull $GEN_IMAGE" >&2; rm -rf "$cfg"; return 1; }
  printf '%s' "$token" | DOCKER_CONFIG="$cfg" docker login ghcr.io -u "${GHCR_USER:-garyachy}" --password-stdin >/dev/null 2>&1 &&
    DOCKER_CONFIG="$cfg" docker pull -q "$GEN_IMAGE" >/dev/null
  local rc=$?
  rm -rf "$cfg"
  return $rc
}

for h in $(printf '%s\n' "$SENDER_HOST" "$RECEIVER_HOST" | sort -u); do
  if $SSH "$LAB_SSH_USER@$h" "sg docker -c 'docker image inspect $GEN_IMAGE'" >/dev/null 2>&1; then
    echo ">> gen image $GEN_IMAGE already on ${h%%.*}"
    continue
  fi
  fetch_local || exit 1
  echo ">> gen image $GEN_IMAGE -> ${h%%.*}"
  docker save "$GEN_IMAGE" | $SSH "$LAB_SSH_USER@$h" "sg docker -c 'docker load'" >/dev/null
done
