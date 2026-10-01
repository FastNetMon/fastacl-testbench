#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"
SSH="ssh $SSH_OPTS"

HOST="${1:?usage: cx7-recover.sh <machine> [--pci <pci>] [--no-verify]}"; shift || true
PCI=""; VERIFY=1
while [ $# -gt 0 ]; do
  case "$1" in
    --pci)       PCI="$2"; shift 2 ;;
    --no-verify) VERIFY=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$HOST" in
  lava1) FQDN="${LAB_HOST_lava:?LAB_HOST_lava not set}"; PCI="${PCI:-0000:01:00.1}"; IFACES="enp1s0f1np1 enp1s0f0np0" ;;
  *)     FQDN="${HOST}"; PCI="${PCI:-}"; IFACES="" ;;
esac
USER_HOST="$LAB_SSH_USER@$FQDN"

echo "=== ConnectX-7 DevX-wedge recovery: $HOST ($FQDN) ==="

echo ""
echo "[1/4] AC-drain power cycle via PDU (pdu.sh cycle $HOST)..."
"$SCRIPT_DIR/pdu.sh" cycle "$HOST" --yes

echo ""
echo "[2/4] Waiting for $HOST to boot..."
back=0
for i in $(seq 1 18); do
  sleep 20
  if $SSH "$USER_HOST" 'echo up' >/dev/null 2>&1; then
    echo "  back after ~$((i*20))s"; back=1; break
  fi
done
[ "$back" = 1 ] || { echo "  FAILED: $HOST did not return in ~6 min — check POST / reseat the card"; exit 1; }

echo ""
echo "[3/4] Bringing CX-7 links up..."
for ifc in $IFACES; do
  $SSH "$USER_HOST" "sudo ip link set $ifc up" 2>/dev/null || true
done
sleep 4
for ifc in $IFACES; do
  st=$($SSH "$USER_HOST" "cat /sys/class/net/$ifc/carrier 2>/dev/null; cat /sys/class/net/$ifc/speed 2>/dev/null" | tr '\n' ' ')
  echo "  $ifc: carrier+speed = $st"
done
if $SSH "$USER_HOST" 'sudo dmesg 2>/dev/null | tail -40 | grep -qiE "Fatal error 3|health recovery failed|drop queue CQ creation failed"'; then
  echo "  WARNING: mlx5 still logging fatal/DevX errors after the drain."
  echo "           Cycle once more, or reseat / move the card to a Gen5 x16 slot."
fi

if [ "$VERIFY" = 1 ] && [ -n "$PCI" ]; then
  echo ""
  echo "[4/4] Verifying DPDK/DevX with a short testpmd probe on $PCI..."
  ok=$($SSH "$USER_HOST" "sudo rm -f /dev/hugepages/cx7vfy* 2>/dev/null
    printf 'quit\n' | sudo timeout 40 dpdk-testpmd -l 0-2 -n 4 -a $PCI --file-prefix cx7vfy -- --rxq=2 --txq=2 -i 2>&1 | \
      grep -ciE 'failed to set defaults flows|drop queue CQ creation failed|Cannot create drop|Could not find requested'
    sudo rm -f /dev/hugepages/cx7vfy* 2>/dev/null" 2>/dev/null)
  if [ "${ok:-1}" = 0 ]; then
    echo "  DevX OK — DPDK claimed the port with no flow errors.  Ready for TRex/VPP."
  else
    echo "  DevX STILL BROKEN — DPDK cannot claim the port cleanly."
    echo "  Do NOT mlxfwreset (it makes this worse).  AC-drain again, and if it"
    echo "  recurs, the Gen5 x4 slot is the likely cause: reseat / move to x16."
    exit 1
  fi
else
  echo ""
  echo "[4/4] Skipped DPDK verify (pass a PCI + drop --no-verify to enable)."
fi

echo ""
echo "=== $HOST recovered.  Start TRex/VPP normally. ==="
