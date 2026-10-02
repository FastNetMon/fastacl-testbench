#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$LAB_DIR/vars.sh"
source "$LAB_DIR/../common/vpp.sh"

echo "=== FastACL Flame (TRex) ==="
echo "  Port 0 (sender):   PCI $SENDER_PCI  MAC $SENDER_MAC"
echo "  Port 1 (receiver): PCI $RECEIVER_PCI MAC $RECEIVER_MAC"
# TREX_RATE is still empty here when it is about to be derived below, which
# printed a bare "Rate:" line; show the target that will be used instead.
echo "  Rate: ${TREX_RATE:-${TREX_TARGET_MPPS:+${TREX_TARGET_MPPS} Mpps (target)}}"
echo ""

vpp_ensure_hugepages_2m "$TREX_HUGEPAGES_2M"
if [ "$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages 2>/dev/null || echo 0)" -eq 0 ]; then
  echo "ERROR: 0 hugepages — TRex cannot start." >&2; exit 1
fi

"$LAB_DIR/setup/perf-tune.sh" "$GEN"
echo ""

echo "Ensuring CQE_COMPRESSION=AGGRESSIVE on generator NICs..."
vpp_ensure_cqe_aggressive "$SENDER_PCI" "$RECEIVER_PCI"
echo ""

echo "DUT RSS key (vars.sh): ${DUT_RSS_KEY:0:16}..."
if [ ${#DUT_RSS_KEY} -lt 80 ]; then
  echo "  WARNING: DUT_RSS_KEY not set in vars.sh — attacks.py will use compiled-in default"
  DUT_RSS_KEY=""
fi
echo ""

if [ ! -x "$TREX_DIR/t-rex-64" ]; then
  echo "ERROR: $TREX_DIR/t-rex-64 not found. Is the TRex image built?" >&2
  exit 1
fi

TREX_WORKER_LIST="$(python3 - <<EOF
import re, sys
s = "$TREX_WORKER_CORES"
result = []
for part in s.split(','):
    part = part.strip()
    m = re.fullmatch(r'(\d+)-(\d+)', part)
    if m:
        result.extend(range(int(m.group(1)), int(m.group(2)) + 1))
    else:
        result.append(int(part))
print(', '.join(str(x) for x in result))
EOF
)"
TREX_WORKER_COUNT=$(echo "$TREX_WORKER_LIST" | tr -cd ',' | wc -c)
TREX_WORKER_COUNT=$(( TREX_WORKER_COUNT + 1 ))

CONF_DIR="$SCRIPT_DIR/conf"
sed \
    -e "s|__SENDER_PCI__|$SENDER_PCI|g" \
    -e "s|__RECEIVER_PCI__|$RECEIVER_PCI|g" \
    -e "s|__SENDER_IP__|$SENDER_IP|g" \
    -e "s|__RECEIVER_IP__|$RECEIVER_IP|g" \
    -e "s|__TREX_MASTER_CORE__|$TREX_MASTER_CORE|g" \
    -e "s|__TREX_LATENCY_CORE__|$TREX_LATENCY_CORE|g" \
    -e "s|__TREX_SOCKET__|${TREX_SOCKET:-0}|g" \
    -e "s|__TREX_WORKER_LIST__|$TREX_WORKER_LIST|g" \
    "$CONF_DIR/trex_cfg.yaml.tmpl" > /etc/trex_cfg.yaml
[ -n "${TREX_PORT_MTU:-}" ] && sed -i "/^  version /a\\  port_mtu        : $TREX_PORT_MTU" /etc/trex_cfg.yaml

echo "Rendered /etc/trex_cfg.yaml (workers: $TREX_WORKER_LIST, count: $TREX_WORKER_COUNT)"

echo "Flushing kernel IPs from $GEN_IFACE0 and $GEN_IFACE1..."
ip addr flush dev "$GEN_IFACE0" 2>/dev/null || true
ip addr flush dev "$GEN_IFACE1" 2>/dev/null || true

pkill -x t-rex-64 2>/dev/null || true
sleep 1
rm -f /dev/hugepages/rtemap_* 2>/dev/null || true

echo "Starting t-rex-64..."
cd "$TREX_DIR"
./t-rex-64 -i --iom 0 --no-scapy-server --no-ofed-check --no-watchdog -c "${TREX_CORES:-$TREX_WORKER_COUNT}" > /tmp/trex.log 2>&1 &
TREX_PID=$!
echo "TRex PID: $TREX_PID"

echo "Waiting for TRex API..."
DEADLINE=$(( $(date +%s) + 60 ))
while true; do
  if TREX_DIR="$TREX_DIR" PYTHONPATH=/src/labs/hw/gen/conf python3 - <<'PYEOF' 2>/dev/null; then
import _trex_env  # noqa: F401  (shared TRex sys.path bootstrap)
from trex.stl.api import STLClient
c = STLClient()
c.connect()
c.disconnect()
PYEOF
    break
  fi
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "ERROR: TRex API did not become ready within 60 seconds." >&2
    echo "Last TRex log:" >&2
    tail -20 /tmp/trex.log >&2
    exit 1
  fi
  sleep 2
done
echo "TRex API ready."
[ "${GEN_IDLE:-0}" = 1 ] && { echo "GEN_IDLE=1: TRex left idle for an external client."; wait "$TREX_PID"; exit $?; }

# TRex's percentage multiplier is a share of the port's LINE rate, so the right
# way to offer exactly TREX_TARGET_GBPS on any card is (target / link speed).
# The lab NICs come up at 200 G, so 100 G is 50% there and 100% on a 100 G card.
if [ -z "${TREX_RATE:-}" ] && [ "${TREX_TARGET_MPPS:-0}" != "0" ]; then
  # TRex takes a packet-rate multiplier directly, so this needs no link-speed
  # arithmetic and offers the same pps on a 100 G or 200 G card.
  TREX_RATE="${TREX_TARGET_MPPS}mpps"
  echo "  Rate: ${TREX_TARGET_MPPS} Mpps target -> TRex mult $TREX_RATE"
fi
if [ -z "${TREX_RATE:-}" ]; then
  _link_mbps=$(cat "/sys/class/net/$GEN_IFACE0/speed" 2>/dev/null || echo 0)
  if [ "${_link_mbps:-0}" -gt 0 ]; then
    TREX_RATE=$(awk -v t="$TREX_TARGET_GBPS" -v l="$_link_mbps" \
      'BEGIN{p=t*1000.0/l*100.0; if (p>100) p=100; printf "%.4g%%", p}')
    echo "  Rate: ${TREX_TARGET_GBPS} Gbps target on a $((_link_mbps/1000)) G link -> TRex mult $TREX_RATE"
  else
    TREX_RATE="100%"
    echo "  WARNING: could not read $GEN_IFACE0 link speed — falling back to 100% of line rate"
  fi
fi

exec env \
  TREX_DIR="$TREX_DIR" \
  SENDER_IP="$SENDER_IP" \
  SENDER_MAC="$SENDER_MAC" \
  DUT_LEFT_MAC="$DUT_LEFT_MAC" \
  TREX_RATE="$TREX_RATE" \
  TREX_PKTSIZE="${TREX_PKTSIZE:-64}" \
  TREX_STREAM_MODE="${TREX_STREAM_MODE:-random-dst}" \
  TREX_ATTACK="${TREX_ATTACK:-icmp-flood}" \
  DUT_NUM_QUEUES="$DUT_NUM_QUEUES" \
  DUT_RSS_KEY="$DUT_RSS_KEY" \
  python3 /src/labs/hw/gen/conf/run.py
