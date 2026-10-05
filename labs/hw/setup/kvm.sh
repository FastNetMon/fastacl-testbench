#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 FastNetMon (fastnetmon.com)

# Out-of-band control of a host through its JetKVM (alice, bob: no BMC).
#
#   kvm.sh <host> {status|reboot|sysrq-reboot|on|off|cycle|reset}
#
# reboot and sysrq-reboot type on the host's keyboard, so they need a live
# kernel: reboot sends Ctrl+Alt+Del, sysrq-reboot sends Alt+SysRq S, U, B for a
# host whose userspace hangs.  on/off/cycle/reset press the motherboard buttons
# and need the JetKVM ATX extension wired and active; status shows whether it is.
#
# The JetKVM sits on the management LAN, so calls run on LAB_PROXY with the
# jetkvm-rpc client (labs/hw/kvm/jetkvm-rpc), built here for the proxy's
# architecture and copied over on first use.  The password reaches the proxy on
# stdin only.  Every call logs in afresh and takes over the KVM session, which
# signs out anyone using the JetKVM web UI at that moment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

NAME="${1:?usage: kvm.sh <host> status|reboot|sysrq-reboot|on|off|cycle|reset}"
CMD="${2:-status}"
_h="LAB_KVM_HOST_$NAME"; _p="LAB_KVM_PASS_$NAME"
KVM_HOST="${!_h:-}"; KVM_PASS="${!_p:-}"
[ -n "$KVM_HOST" ] && [ -n "$KVM_PASS" ] || { echo "kvm.sh: no $_h / $_p in lab.env" >&2; exit 1; }
PROXY="${IPMI_PROXY:-${LAB_PROXY:-}}"
[ -n "$PROXY" ] || { echo "kvm.sh: LAB_PROXY is not set" >&2; exit 1; }
SSH="ssh $SSH_OPTS -o BatchMode=yes"
SRC="$SCRIPT_DIR/../kvm/jetkvm-rpc"
REMOTE_BIN='.cache/fastacl-testbench/jetkvm-rpc'

ensure_client() {
  local arch goarch bin
  arch=$($SSH "$PROXY" uname -m)
  case "$arch" in aarch64|arm64) goarch=arm64;; x86_64) goarch=amd64;; *) echo "kvm.sh: proxy arch $arch" >&2; return 1;; esac
  bin="$SCRIPT_DIR/../kvm/bin/jetkvm-rpc-$goarch"
  if [ ! -x "$bin" ] || [ -n "$(find "$SRC" -newer "$bin" -type f | head -1)" ]; then
    mkdir -p "$(dirname "$bin")"
    local log
    log=$(docker run --rm -v "$SRC":/src:ro -v "$(dirname "$bin")":/out -w /src \
      -e GOARCH="$goarch" -e CGO_ENABLED=0 -e GOFLAGS=-modcacherw golang:1.24 \
      go build -trimpath -ldflags "-s -w" -o "/out/jetkvm-rpc-$goarch" . 2>&1) \
      || { echo "kvm.sh: building jetkvm-rpc failed:" >&2; echo "$log" >&2; return 1; }
  fi
  if [ "$($SSH "$PROXY" "sha256sum $REMOTE_BIN 2>/dev/null | cut -d' ' -f1")" != "$(sha256sum "$bin" | cut -d' ' -f1)" ]; then
    $SSH "$PROXY" "mkdir -p \$(dirname $REMOTE_BIN)"
    scp -q $SSH_OPTS "$bin" "$PROXY:$REMOTE_BIN"
  fi
}

rpc() {
  local args="" a
  for a in "$@"; do args="$args '$a'"; done
  printf '%s\n' "$KVM_PASS" | $SSH "$PROXY" "read -r P; JETKVM_PASSWORD=\"\$P\" $REMOTE_BIN '$KVM_HOST'$args"
}

key() { rpc keyboardReport "{\"modifier\":$1,\"keys\":[$2]}" keyboardReport '{"modifier":0,"keys":[]}' >/dev/null; }

atx_active() { [ "$(rpc getActiveExtension | sed -n 's/^getActiveExtension: //p')" = '"atx-power"' ]; }
need_atx() {
  atx_active && return 0
  echo "kvm.sh: $NAME's JetKVM has no active ATX extension -- it cannot press power/reset." >&2
  echo "  Fit the ATX board and enable it, or use: kvm.sh $NAME reboot (needs a live kernel)." >&2
  exit 1
}
powered() { rpc getATXState | grep -q '"power":true'; }
atx() { rpc setATXPowerAction "{\"action\":\"$1\"}" >/dev/null; }

ensure_client
case "$CMD" in
  status)
    echo "=== $NAME JetKVM ($KVM_HOST) ==="
    rpc getLocalVersion '{}' getActiveExtension '{}' getATXState '{}' | sed 's/^/  /'
    atx_active || echo "  (no ATX extension: power state above is not wired)"
    ;;
  reboot)
    echo "=== $NAME: Ctrl+Alt+Del via JetKVM ==="
    key 5 76
    ;;
  sysrq-reboot)
    echo "=== $NAME: Alt+SysRq S, U, B via JetKVM ==="
    key 4 "70,22"; sleep 3
    key 4 "70,24"; sleep 3
    key 4 "70,5"
    ;;
  on)
    need_atx
    powered && { echo "$NAME is already on."; exit 0; }
    atx power-short
    ;;
  off)
    need_atx
    powered || { echo "$NAME is already off."; exit 0; }
    atx power-long
    ;;
  reset)
    need_atx
    atx reset
    ;;
  cycle)
    need_atx
    echo "=== $NAME hard power-cycle via JetKVM ATX ==="
    powered && atx power-long
    for _ in $(seq 1 20); do powered || break; sleep 2; done
    sleep 5
    for _ in $(seq 1 3); do
      atx power-short; sleep 6
      powered && { echo "Power-cycle complete.  $NAME booting..."; exit 0; }
    done
    echo "WARNING: $NAME is still OFF after the cycle.  Retry: $0 $NAME on" >&2
    exit 1
    ;;
  *)
    echo "Usage: $0 <host> {status|reboot|sysrq-reboot|on|off|cycle|reset}"
    exit 1
    ;;
esac
