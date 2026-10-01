#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

set -euo pipefail

HW="$(cd "$(dirname "$0")" && pwd)"
src="${1:?usage: publish-results.sh <report-dir> <name>}"
name="${2:?usage: publish-results.sh <report-dir> <name>}"
branch="${PUBLISH_BRANCH:-main}"
wt="$(mktemp -d)"


publish() {
  git fetch -q origin "$branch"
  git worktree add -q --detach "$wt" "origin/$branch"
  mkdir -p "$wt/reports/$name"
  for f in report.md results.csv run.jsonl; do
    [ -f "$src/$f" ] && cp "$src/$f" "$wt/reports/$name/$f"
  done

  python3 "$HW/reports-index.py" "$wt/reports" > "$wt/reports/README.md"

  git -C "$wt" add reports
  git -C "$wt" -c user.name=fastacl-testbench \
    -c user.email=fastacl-testbench@users.noreply.github.com commit -q -m "report: $name [skip ci]"
  git -C "$wt" push -q origin "HEAD:$branch"
}

for attempt in 1 2 3; do
  if publish; then
    git worktree remove --force "$wt"
    echo "published reports/$name/ to $branch"
    exit 0
  fi
  git worktree remove --force "$wt" 2>/dev/null || true
  wt="$(mktemp -d)"
  echo "publish attempt $attempt failed, retrying" >&2
  sleep 5
done
exit 1
