#!/usr/bin/env bash

LAB_ENV="${LAB_ENV:-$(dirname "${BASH_SOURCE[0]}")/lab.env}"
[ -f "$LAB_ENV" ] && . "$LAB_ENV"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15"
LAB_SSH_USER="${LAB_SSH_USER:-$USER}"

DUT="${DUT:-server1}"
case "$DUT" in
  server1)
    DUT_HOST="${LAB_HOST_server1:-}"
    DUT_PCI_0="0000:81:00.0"; DUT_IFACE_0="enp129s0f0np0"
    DUT_PCI_1="0000:81:00.1"; DUT_IFACE_1="enp129s0f1np1"
    DUT_INGRESS_DEFAULT="0000:81:00.1"
    DUT_LEFT_MAC_DEFAULT="${LAB_MAC_LEFT_server1:-}"
    DUT_RIGHT_MAC_DEFAULT="${LAB_MAC_RIGHT_server1:-}"
    DUT_IPMI_HOST="${LAB_IPMI_HOST_server1:-}"; DUT_IPMI_USER="${LAB_IPMI_USER_server1:-}"; DUT_IPMI_PASS="${LAB_IPMI_PASS_server1:-}"
    ;;
  epyc)
    DUT_HOST="${LAB_HOST_epyc:-}"
    DUT_PCI_0="0000:03:00.0"; DUT_IFACE_0="enp3s0f0np0"
    DUT_PCI_1="0000:03:00.1"; DUT_IFACE_1="enp3s0f1np1"
    DUT_INGRESS_DEFAULT="0000:03:00.1"
    DUT_LEFT_MAC_DEFAULT="${LAB_MAC_LEFT_epyc:-}"
    DUT_RIGHT_MAC_DEFAULT="${LAB_MAC_RIGHT_epyc:-}"
    DUT_IPMI_HOST="${LAB_IPMI_HOST_epyc:-}"; DUT_IPMI_USER="${LAB_IPMI_USER_epyc:-}"; DUT_IPMI_PASS="${LAB_IPMI_PASS_epyc:-}"
    # BlueField-3 uplink ownership.  "nic" (SEPARATED_HOST) lets the EPYC host
    # drive both ports itself, matching how server1 runs; "dpu" (EMBEDDED_CPU)
    # hands them to the DPU Arm for the on-DPU bench.  Switching costs a cold
    # power cycle -- see setup/mellanox-init.sh --bf-mode.
    DUT_BF_MODE="${DUT_BF_MODE:-nic}"
    ;;
  epyc-cx8)
    # epyc-sp5 with alice's ConnectX-8 in CPU SLOT5 (BlueField-3 removed
    # 2026-10-07), cabled port to port with bob like alice was.
    DUT_HOST="${LAB_HOST_epyc:-}"
    DUT_PCI_0="0000:41:00.0"; DUT_IFACE_0="enp65s0f0np0"
    DUT_PCI_1="0000:41:00.1"; DUT_IFACE_1="enp65s0f1np1"
    DUT_INGRESS_DEFAULT="0000:41:00.1"
    DUT_LEFT_MAC_DEFAULT="${LAB_MAC_LEFT_epyc_cx8:-}"
    DUT_RIGHT_MAC_DEFAULT="${LAB_MAC_RIGHT_epyc_cx8:-}"
    DUT_IPMI_HOST="${LAB_IPMI_HOST_epyc:-}"; DUT_IPMI_USER="${LAB_IPMI_USER_epyc:-}"; DUT_IPMI_PASS="${LAB_IPMI_PASS_epyc:-}"
    ;;
  epyc-platform)
    # epyc-sp5 as a pure sink for the platform ceiling (platform-ceiling.sh):
    # two ConnectX-8 (41:00 in CPU SLOT5, 0a:00) and the BlueField-3 in NIC mode
    # (03:00), every port ingress, fed by server1.  DUT_PCI_0/1 keep the
    # single-card helpers working; the sink ports are SINK_PORTS.
    DUT_HOST="${LAB_HOST_epyc:-}"
    DUT_PCI_0="0000:41:00.0"; DUT_IFACE_0="enp65s0f0np0"
    DUT_PCI_1="0000:41:00.1"; DUT_IFACE_1="enp65s0f1np1"
    DUT_INGRESS_DEFAULT="0000:41:00.1"
    DUT_LEFT_MAC_DEFAULT=""; DUT_RIGHT_MAC_DEFAULT=""
    DUT_IPMI_HOST="${LAB_IPMI_HOST_epyc:-}"; DUT_IPMI_USER="${LAB_IPMI_USER_epyc:-}"; DUT_IPMI_PASS="${LAB_IPMI_PASS_epyc:-}"
    # pci:name:rx-queues:kernel-iface, in TRex port order (gen port i feeds sink port i).
    # 32 workers: at full load VPP drops 346 Mpps with 32, 148 with 62 (buffer-pool contention).
    SINK_PORTS="${SINK_PORTS:-0000:41:00.1:cx8a-p1:8:enp65s0f1np1 0000:0a:00.1:cx8b-p1:8:enp10s0f1np1 0000:0a:00.0:cx8b-p0:4:enp10s0f0np0 0000:41:00.0:cx8a-p0:4:enp65s0f0np0 0000:03:00.0:bf3-p0:4:enp3s0f0np0 0000:03:00.1:bf3-p1:4:enp3s0f1np1}"
    # These ports carry a ConnectX-5 DAC that links only with autonegotiation off.
    SINK_FORCE_100G="${SINK_FORCE_100G:-enp65s0f0np0}"
    ;;
  alice|bob)
    DUT_HOST_VAR="LAB_HOST_$DUT"; DUT_HOST="${!DUT_HOST_VAR:-}"
    DUT_PCI_0="0000:01:00.0"; DUT_IFACE_0="enp1s0f0np0"
    DUT_PCI_1="0000:01:00.1"; DUT_IFACE_1="enp1s0f1np1"
    DUT_INGRESS_DEFAULT="0000:01:00.1"
    _l="LAB_MAC_LEFT_$DUT"; _r="LAB_MAC_RIGHT_$DUT"
    DUT_LEFT_MAC_DEFAULT="${!_l:-}"
    DUT_RIGHT_MAC_DEFAULT="${!_r:-}"
    DUT_IPMI_HOST=""; DUT_IPMI_USER=""; DUT_IPMI_PASS=""
    # No BMC: out-of-band control is the host's JetKVM (setup/kvm.sh).
    _k="LAB_KVM_HOST_$DUT"; DUT_KVM_HOST="${!_k:-}"
    DUT_HUGEPAGES_1G=0
    DUT_SKIP_OFED=1
    ;;
  *)
    echo "vars.sh: unknown DUT='$DUT' (use 'server1', 'epyc', 'epyc-cx8', 'epyc-platform', 'alice' or 'bob')" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

GEN="${GEN:-flame}"
case "$GEN" in
  lava)
    # lava1 (Ryzen 9950X) drives the epyc-sp5 DUT with TWO separate CX5-Ex cards,
    # one 100G DAC each to a BlueField-3 port: card B (02:00.0) -> epyc INGRESS
    # (03:00.1) is the sender, card A (01:00.0) -> epyc EGRESS (03:00.0) is the
    # receiver. Two cards sidestep the single dual-port ASIC RX ceiling.
    SENDER_HOST="${LAB_HOST_lava:-}"
    RECEIVER_HOST="${LAB_HOST_lava:-}"
    SENDER_PCI="0000:02:00.0"
    RECEIVER_PCI="0000:01:00.0"
    SENDER_MAC="${LAB_MAC_SENDER_lava:-}"
    RECEIVER_MAC="${LAB_MAC_RECEIVER_lava:-}"
    GEN_IFACE0="enp2s0f0np0"
    GEN_IFACE1="enp1s0f0np0"
    TREX_MASTER_CORE=0
    TREX_LATENCY_CORE=16
    TREX_WORKER_CORES="1-15,17-31"
    TREX_SOCKET=0
    TREX_HUGEPAGES_2M=2048
    GEN_HUGEPAGES_1G=0
    GEN_SKIP_OFED=1
    ;;
  flame)
    SENDER_HOST="${LAB_HOST_flame:-}"
    RECEIVER_HOST="${LAB_HOST_flame:-}"
    SENDER_PCI="0000:2b:00.1"
    RECEIVER_PCI="0000:2b:00.0"
    SENDER_MAC="${LAB_MAC_SENDER_flame:-}"
    RECEIVER_MAC="${LAB_MAC_RECEIVER_flame:-}"
    GEN_IFACE0="enp43s0f1np1"
    GEN_IFACE1="enp43s0f0np0"
    TREX_MASTER_CORE=0
    TREX_LATENCY_CORE=8
    TREX_WORKER_CORES="1-7,9-15"
    TREX_SOCKET=0
    TREX_HUGEPAGES_2M=2048
    GEN_HUGEPAGES_1G=0
    GEN_SKIP_OFED=1
    ;;
  dell)
    SENDER_HOST="${LAB_HOST_dell:-}"
    RECEIVER_HOST="${LAB_HOST_dell:-}"
    SENDER_PCI="0000:d8:00.1"
    RECEIVER_PCI="0000:3b:00.0"
    SENDER_MAC="${LAB_MAC_SENDER_dell:-}"
    RECEIVER_MAC="${LAB_MAC_RECEIVER_dell:-}"
    GEN_IFACE0="enp216s0f1np1"
    GEN_IFACE1="enp59s0f0np0"
    TREX_MASTER_CORE=1
    TREX_LATENCY_CORE=3
    TREX_WORKER_CORES="5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75"
    TREX_SOCKET=1
    TREX_HUGEPAGES_2M=4096
    ;;
  alice|bob)
    _h="LAB_HOST_$GEN"
    SENDER_HOST="${!_h:-}"
    RECEIVER_HOST="${!_h:-}"
    SENDER_PCI="0000:01:00.1"
    RECEIVER_PCI="0000:01:00.0"
    _s="LAB_MAC_SENDER_$GEN"; _r="LAB_MAC_RECEIVER_$GEN"
    SENDER_MAC="${!_s:-}"
    RECEIVER_MAC="${!_r:-}"
    GEN_IFACE0="enp1s0f1np1"
    GEN_IFACE1="enp1s0f0np0"
    TREX_MASTER_CORE=0
    TREX_LATENCY_CORE=16
    TREX_WORKER_CORES="1-15,17-31"
    TREX_SOCKET=0
    TREX_HUGEPAGES_2M=2048
    GEN_HUGEPAGES_1G=0
    GEN_SKIP_OFED=1
    GEN_DOCKERFILE="docker/Dockerfile.trex-src"
    GEN_IMAGE="ghcr.io/garyachy/fastacl-testbench-trex:27e0153b"
    TREX_PORT_MTU=9000
    TREX_TARGET_GBPS=400
    TREX_TARGET_GBPS_MIXED=400
    ;;
  server1)
    # server1 (EPYC 7742) as a six-port generator for epyc-platform: two
    # ConnectX-7 (200G) and three ConnectX-5 Ex (100G).  TREX_PCI_LIST order is
    # the TRex port order; port i feeds SINK_PORTS entry i on the DUT.
    SENDER_HOST="${LAB_HOST_server1:-}"
    RECEIVER_HOST="${LAB_HOST_server1:-}"
    SENDER_PCI="0000:81:00.1"
    RECEIVER_PCI="0000:c2:00.0"
    SENDER_MAC=""; RECEIVER_MAC=""
    GEN_IFACE0="enp129s0f1np1"
    GEN_IFACE1="enp194s0f0np0"
    TREX_PCI_LIST="${TREX_PCI_LIST:-0000:81:00.1 0000:c2:00.0 0000:01:00.1 0000:01:00.0 0000:82:00.0 0000:c1:00.0}"
    GEN_FORCE_100G="${GEN_FORCE_100G:-enp1s0f0np0}"
    TREX_PORT_MTU=9000
    TREX_MASTER_CORE=0
    TREX_LATENCY_CORE=63
    TREX_WORKER_CORES="1-48"
    TREX_SOCKET=0
    TREX_HUGEPAGES_2M=8192
    GEN_HUGEPAGES_1G=0
    GEN_SKIP_OFED=1
    GEN_DOCKERFILE="docker/Dockerfile.trex-src"
    GEN_IMAGE="ghcr.io/garyachy/fastacl-testbench-trex:27e0153b"
    ;;
  *)
    echo "vars.sh: unknown GEN='$GEN' (use 'lava', 'flame', 'dell', 'alice', 'bob' or 'server1')" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

IPMI_PROXY="${IPMI_PROXY:-${LAB_PROXY:-}}"

DELL_IDRAC_HOST="${LAB_DELL_IDRAC_HOST:-}"
DELL_IDRAC_USER="${LAB_DELL_IDRAC_USER:-}"
DELL_IDRAC_PASS="${LAB_DELL_IDRAC_PASS:-}"

PDU1_HOST="${LAB_PDU1_HOST:-}"
PDU2_HOST="${LAB_PDU2_HOST:-}"
PDU_USER="${LAB_PDU_USER:-}"
PDU1_PASS="${LAB_PDU1_PASS:-}"
PDU2_PASS="${LAB_PDU2_PASS:-}"
PDU_PROXY="${PDU_PROXY:-${LAB_PROXY:-}}"
PDU_MAP_flame1="${LAB_PDU_MAP_flame1:-}"
PDU_MAP_lava1="${LAB_PDU_MAP_lava1:-}"
PDU_MAP_server1="${LAB_PDU_MAP_server1:-}"
PDU_MAP_epyc_sp5="${LAB_PDU_MAP_epyc_sp5:-}"

DUT_INGRESS_PORT="${DUT_INGRESS_PORT:-$DUT_INGRESS_DEFAULT}"

_dut_iface_for() { case "$1" in "$DUT_PCI_0") echo "$DUT_IFACE_0" ;; "$DUT_PCI_1") echo "$DUT_IFACE_1" ;; esac; }

if [ "$DUT_INGRESS_PORT" = "$DUT_PCI_0" ]; then
  _DUT_L="$DUT_PCI_0"; _DUT_R="$DUT_PCI_1"
else
  _DUT_L="$DUT_PCI_1"; _DUT_R="$DUT_PCI_0"
fi
DUT_PCI_LEFT="${DUT_PCI_LEFT:-$_DUT_L}"
DUT_PCI_RIGHT="${DUT_PCI_RIGHT:-$_DUT_R}"
DUT_PCI_LEFT_PF="${DUT_PCI_LEFT_PF:-$_DUT_L}"
DUT_PCI_RIGHT_PF="${DUT_PCI_RIGHT_PF:-$_DUT_R}"
# Live-resolve the DUT NIC MAC over SSH so a re-imaged host never serves a stale
# address.  MUST stay safe when vars.sh is sourced under `set -euo pipefail`
# (perf-tune.sh, start.sh) and inside the DUT/gen containers, which have neither
# ssh nor tailnet: a container marker + ssh guard short-circuit to the per-DUT
# static default below, and every failure path returns success so `set -e` never
# trips.  Precedence: environment override > live probe > per-DUT profile default.
_dut_mac_live() {
  [ -f /.dockerenv ] && { printf ''; return 0; }
  command -v ssh >/dev/null 2>&1 || { printf ''; return 0; }
  local m=""
  m=$(timeout 6 ssh $SSH_OPTS "$LAB_SSH_USER@$DUT_HOST" "cat /sys/class/net/$1/address 2>/dev/null" </dev/null 2>/dev/null | tr -d '\r\n') || m=""
  printf '%s' "$m"
  return 0
}
DUT_LEFT_MAC="${DUT_LEFT_MAC:-$(_dut_mac_live "$(_dut_iface_for "$DUT_PCI_LEFT_PF")")}"
DUT_LEFT_MAC="${DUT_LEFT_MAC:-$DUT_LEFT_MAC_DEFAULT}"
DUT_RIGHT_MAC="${DUT_RIGHT_MAC:-$(_dut_mac_live "$(_dut_iface_for "$DUT_PCI_RIGHT_PF")")}"
DUT_RIGHT_MAC="${DUT_RIGHT_MAC:-$DUT_RIGHT_MAC_DEFAULT}"

DUT_LINK_MAX_FWRESET="${DUT_LINK_MAX_FWRESET:-2}"

SENDER_IP="10.0.1.1"
SENDER_PREFIX="24"
DUT_LEFT_IP="10.0.1.2"
DUT_LEFT_PREFIX="24"
DUT_RIGHT_IP="10.0.2.1"
DUT_RIGHT_PREFIX="24"
RECEIVER_IP="10.0.2.2"
RECEIVER_PREFIX="24"

DUT_MAIN_CORE=0
DUT_POLL_WORKERS="${DUT_POLL_WORKERS:-32}"
DUT_WORKER_CORES="1-${DUT_POLL_WORKERS}"
DUT_RX_DESC="${DUT_RX_DESC:-4096}"
if [ "${DUT_POLL_WORKERS}" -gt 32 ]; then
  DUT_TX_DESC="${DUT_TX_DESC:-2048}"
else
  DUT_TX_DESC="${DUT_TX_DESC:-4096}"
fi

DUT_HEAP_PAGE="${DUT_HEAP_PAGE:-2M}"
DUT_BUFFERS_PER_NUMA="${DUT_BUFFERS_PER_NUMA:-2097152}"
DUT_NUM_QUEUES="${DUT_NUM_QUEUES:-$DUT_POLL_WORKERS}"

TREX_DIR="/opt/trex"
# Offer exactly this much traffic, regardless of what the generator card could
# push.  TRex's "100%" means 100% of the PORT's line rate -- and the lab NICs
# negotiate 200 G -- so "100%" silently offered ~2x the 100 G we claim to test,
# over-driving the link and making every adapter-loss threshold a function of the
# generator hardware (swap the card, re-tune the thresholds).  gen/start.sh turns
# this target into the right TRex multiplier from the measured link speed, so the
# offered load is identical on a 100 G or 200 G card.
TREX_TARGET_GBPS="${TREX_TARGET_GBPS:-100}"
# Packet-rate target; takes precedence over TREX_TARGET_GBPS when non-zero.
# The DUT's limit is a packet-rate limit, not a bandwidth one -- at a fixed
# 100 Gbps offered, 64 B forwarding loses 9% while 1500 B loses 0.18%, so Gbps
# is the wrong unit to pin the rig to.  127 Mpps is the measured maximum where
# the adapter adds no loss beyond its load-independent ~0.43% floor (rx_prio0
# share stays at the floor's 45-48%, then climbs to 59% at 128 and 83% at 129).
# At or below it every remaining drop is attributable to fastacl, not the NIC.
# Set to 0 to fall back to the Gbps-derived multiplier.
TREX_TARGET_MPPS="${TREX_TARGET_MPPS:-127}"

# The pinning above is a PACKET rate, which is only a fixed bit rate when every
# frame is the same size.  A mixed-size profile averages ~354 B, so the same
# 127 Mpps would demand ~360 Gbps: TRex saturates the 200 G link instead and the
# DUT is offered more bytes than its adapter can DMA, which it reports as
# rx_prio0_buf_discard rather than as anything the filter did.  Mixed profiles
# are therefore pinned by BIT rate, which stays correct if the size mix is ever
# reweighted -- a packet-rate pin would silently drift with it.
TREX_TARGET_GBPS_MIXED="${TREX_TARGET_GBPS_MIXED:-95}"
MIXED_SIZE_ATTACKS="cold-scan-imix mix-sizes"
TREX_RATE="${TREX_RATE:-}"   # leave empty: derived from the targets above
TREX_STREAM_MODE="fixed-dst"

HUGEPAGES_NR="${DUT_HUGEPAGES_1G:-32}"

VPP_BIN="/usr/bin/vpp"
VPPCTL_BIN="/usr/bin/vppctl"
VPP_PLUGIN_PATH="/usr/lib/x86_64-linux-gnu/vpp_plugins"
FASTACL_PLUGIN_PATH=""

SERVER_KERNEL_IFACE0="$(_dut_iface_for "$DUT_PCI_LEFT_PF")"
SERVER_KERNEL_IFACE1="$(_dut_iface_for "$DUT_PCI_RIGHT_PF")"

DPDK_DRIVER="mlx5"

DUT_DEVARGS="${DUT_DEVARGS:-dv_esw_en=0,rxq_cqe_comp_en=4}"

DUT_VF_RIGHT_MAC="${LAB_MAC_DUT_VF_RIGHT:-}"

DUT_RSS_KEY="c62c7a1978c9105bbc4a832d1cc77f2170473a46d8520eeaa8ec8f8e2791785af8a72ded6ed5a270"
