#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="${DUT_IMAGE:-fastacl-dut:current}"

[ -d "$ROOT/bundle/debs" ] || {
  echo "dut-image: $ROOT/bundle/debs missing — extract the FastACL release bundle there first" >&2
  exit 1
}
docker build -q -t "$TAG" -f "$ROOT/docker/Dockerfile.dut" "$ROOT" >/dev/null
docker run --rm "$TAG" dpkg-query -W -f='${Package} ${Version}\n' fastacl-plugin vpp
