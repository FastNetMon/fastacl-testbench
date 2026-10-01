#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/vars.sh"

REBOOT=0; WATCH=600
while [ $# -gt 0 ]; do case "$1" in
  --reboot) REBOOT=1; shift;;
  --watch-secs) WATCH="$2"; shift 2;;
  *) echo "unknown arg: $1"; exit 1;;
esac; done

SSH="ssh $SSH_OPTS"
DUT_SEL="$DUT"          # vars.sh profile name (server1|epyc) before DUT is reused as the ssh target
DUT="$LAB_SSH_USER@$DUT_HOST"
IPMI_PROXY="${IPMI_PROXY:-${LAB_PROXY:-}}"

ipmi() { $SSH "$IPMI_PROXY" "ipmitool -I lanplus -H '$DUT_IPMI_HOST' -U '$DUT_IPMI_USER' -P '$DUT_IPMI_PASS' $*"; }
dut_alive() { timeout 10 $SSH -o ConnectTimeout=6 "$DUT" 'echo ok' 2>/dev/null | grep -q ok; }
vpp_up() {
  timeout 14 $SSH -o ConnectTimeout=8 "$DUT" \
    'CID=$(sg docker -c "docker ps -q --filter name=hw-dut"|head -1); \
     [ -n "$CID" ] && sg docker -c "docker exec $CID vppctl -s /run/vpp/cli.sock show version" 2>/dev/null' \
    2>/dev/null | grep -q "vpp v"
}
n_dut_containers() {
  timeout 14 $SSH -o ConnectTimeout=8 "$DUT" \
    'sg docker -c "docker ps -q --filter name=hw-dut" | wc -l' 2>/dev/null | tr -d '[:space:]'
}
recover() {
  echo ">> WEDGED — auto-recovering via IPMI cold cycle..."
  ipmi power off >/dev/null 2>&1; sleep 20; ipmi power on >/dev/null 2>&1
  for _ in $(seq 1 18); do dut_alive && { echo ">> DUT back online."; return 0; }; sleep 15; done

  local dut_name="${DUT_HOST%%.*}"
  echo ">> IPMI cycle did not recover it — escalating to a PDU AC-drain (cx7-recover $dut_name)..."
  if bash "$SCRIPT_DIR/setup/cx7-recover.sh" "$dut_name" --no-verify 2>&1 | sed 's/^/   /'; then
    for _ in $(seq 1 18); do dut_alive && { echo ">> DUT back online after AC drain."; return 0; }; sleep 15; done
  fi
  echo ">> DUT did NOT come back — manual intervention needed."; return 1
}

if [ "$REBOOT" = 1 ]; then
  echo ">> Rebooting DUT to apply NV config..."
  $SSH "$DUT" 'sudo reboot' >/dev/null 2>&1 || true
  sleep 25
  for _ in $(seq 1 18); do dut_alive && break; sleep 15; done
  echo ">> DUT up."
fi

if [ "$DUT_SEL" = epyc ] && [ -n "${DUT_BF_MODE:-}" ]; then
  "$SCRIPT_DIR/bf-mode.sh" "$DUT_BF_MODE" || { echo ">> BlueField-3 mode switch failed"; exit 1; }
fi

if [ "${SKIP_NIC_INIT:-0}" != "1" ]; then
  echo ">> Initializing DUT Mellanox NIC (verify NV/CQE + firmware reset)..."
  # MFT ships inside the base image, so a host that has never had MFT
  # hand-installed can still configure its NIC: fall back to running
  # mellanox-init in a privileged container.  Hosts that do have MFT keep the
  # original path, so nothing changes for an already-provisioned rig.
  $SSH "$DUT" "HOST_REPO='${HOST_REPO:-fastacl}' DUT_SEL='${DUT_SEL:-server1}' \
     DUT_BF_MODE='${DUT_BF_MODE:-}' NIC_INIT_IMAGE='${NIC_INIT_IMAGE:-fastacl-dut:current}' bash -s" 2>&1 <<'REMOTE' \
    | sed 's/^/   /' || echo "   (mellanox-init reported a problem — continuing; bring-up will verify)"
REPO="$HOME/${HOST_REPO:-fastacl}"
cd "$REPO" || { echo "no repo dir $REPO" >&2; exit 1; }
if command -v mlxconfig >/dev/null 2>&1; then
  sudo -n DUT="$DUT_SEL" DUT_BF_MODE="$DUT_BF_MODE" bash labs/hw/setup/mellanox-init.sh
else
  echo "host has no MFT -- running mellanox-init inside $NIC_INIT_IMAGE"
  sudo -n sg docker -c "docker run --rm --privileged --net=host \
     -v '$REPO':/src -v /dev:/dev -w /src \
     -e DUT='$DUT_SEL' -e DUT_BF_MODE='$DUT_BF_MODE' \
     '$NIC_INIT_IMAGE' bash labs/hw/setup/mellanox-init.sh"
fi
REMOTE
fi

echo ">> Starting DUT VPP container from ~/${HOST_REPO:-fastacl} (graceful scripts)..."
$SSH "$DUT" "HOST_REPO='${HOST_REPO:-fastacl}' DUT='${DUT_SEL:-server1}' \
   DUT_BF_MODE='${DUT_BF_MODE:-}' DUT_POLL_WORKERS='${DUT_POLL_WORKERS:-}' \
   DUT_NUM_QUEUES='${DUT_NUM_QUEUES:-}' DUT_RX_DESC='${DUT_RX_DESC:-}' \
   DUT_TX_DESC='${DUT_TX_DESC:-}' \
   FASTACL_CMAKE_EXTRA='${FASTACL_CMAKE_EXTRA:-}' bash -s" >/dev/null 2>&1 <<'REMOTE'
  REPO="$HOME/${HOST_REPO:-fastacl}"
  cd "$REPO" || { echo "no repo dir $REPO" >&2; exit 1; }
  tmux kill-session -t fastacl-dut 2>/dev/null
  # Killing the tmux session does not stop the container it launched, so a
  # second `run` leaves two VPPs sharing the box.  Stop leftovers first, with
  # the grace period -- a SIGKILL mid-DPDK-release is what wedges the mlx5 fw.
  for _cid in $(sg docker -c 'docker ps -q --filter name=hw-dut'); do
    echo "stopping leftover DUT container $_cid"
    sg docker -c "docker stop -t 30 $_cid" >/dev/null 2>&1
  done
  # Pass the profile explicitly rather than relying on inheritance: tmux does
  # not necessarily carry the caller's environment into a new session, and a
  # dropped DUT here silently selects the server1 profile -- which drives the
  # wrong PCI addresses and reports itself as stuck NIC firmware.
  tmux new-session -d -s fastacl-dut "cd '$REPO' && DUT='${DUT:-server1}' DUT_BF_MODE='${DUT_BF_MODE:-}' DUT_POLL_WORKERS='${DUT_POLL_WORKERS:-}' DUT_NUM_QUEUES='${DUT_NUM_QUEUES:-}' DUT_RX_DESC='${DUT_RX_DESC:-}' DUT_TX_DESC='${DUT_TX_DESC:-}' FASTACL_CMAKE_EXTRA='${FASTACL_CMAKE_EXTRA:-}' sg docker -c 'DUT=\"\$DUT\" DUT_BF_MODE=\"\$DUT_BF_MODE\" DUT_POLL_WORKERS=\"\$DUT_POLL_WORKERS\" DUT_NUM_QUEUES=\"\$DUT_NUM_QUEUES\" DUT_RX_DESC=\"\$DUT_RX_DESC\" DUT_TX_DESC=\"\$DUT_TX_DESC\" FASTACL_CMAKE_EXTRA=\"\$FASTACL_CMAKE_EXTRA\" docker compose -f labs/hw/compose.yaml run --rm dut' 2>&1 | tee '$HOME/dut-boot.log'; sync"
REMOTE

MISS_LIMIT=3
echo ">> Watching for VPP-up vs wedge (up to ${WATCH}s)..."
t=0; misses=0
while [ "$t" -lt "$WATCH" ]; do
  if vpp_up; then
    n="$(n_dut_containers)"
    if [ "${n:-0}" != "1" ]; then
      echo ">> RESULT: FAILED — VPP answered but ${n:-0} DUT containers are running."
      echo "   Exactly one is required: a leftover container serves the PREVIOUS"
      echo "   build and steals CPU from the new one, so every measurement taken"
      echo "   afterwards is against the wrong binary on a contended box."
      exit 3
    fi
    echo ">> SUCCESS — VPP responsive after ${t}s, 1 DUT container. Lab is healthy."
    exit 0
  fi
  if dut_alive; then
    misses=0
  else
    misses=$((misses+1))
    echo ">> Host unreachable at ${t}s (${misses}/${MISS_LIMIT} consecutive)."
    if [ "$misses" -ge "$MISS_LIMIT" ]; then
      echo ">> Host down ${misses} consecutive probes — likely DPDK-init wedge."
      recover; echo ">> RESULT: WEDGED (fix did not prevent the host lockup)."; exit 2
    fi
  fi
  sleep 12; t=$((t+12))
done
echo ">> RESULT: TIMEOUT — VPP not up in ${WATCH}s but host alive; check ~/dut-boot.log on DUT."
exit 3
