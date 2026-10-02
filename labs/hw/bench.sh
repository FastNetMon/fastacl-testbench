#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/vars.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SSH="ssh $SSH_OPTS"
DUT_SSH="$LAB_SSH_USER@$DUT_HOST"
GEN_USER="$LAB_SSH_USER@$SENDER_HOST"
GEN_CONF="/src/labs/hw/gen/conf"
RESULTS_FILE="${RESULTS_FILE:-$REPO_ROOT/results/run.jsonl}"

VALID_ATTACKS="udp-rand syn-flood ack-flood icmp-flood frag-flood fixed-flood-31 fwd-flood-32 tcp-flows-31 cold-scan ip6-cold-scan"

_DUT_CID='sg docker -c "docker ps -q --filter name=hw-dut" | head -1'
_GEN_CID='docker ps -q --filter name=hw-gen | head -1'

dut_exec() { $SSH "$DUT_SSH" "sg docker -c \"docker exec \$($_DUT_CID) $*\""; }
gen_exec() { $SSH "$GEN_USER" "docker exec \$($_GEN_CID) $*"; }

emit() {
  python3 - "$RESULTS_FILE" "$@" <<'PY'
import json, os, sys, time
path, pairs = sys.argv[1], sys.argv[2:]
rec = {"ts": int(time.time()), "dut": os.environ.get("DUT_PROFILE", os.environ.get("PROFILE", "")),
       "gen": os.environ.get("GEN", "")}
for item in pairs:
    key, _, val = item.partition("=")
    try:
        rec[key] = float(val)
    except ValueError:
        rec[key] = val
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "a") as f:
    f.write(json.dumps(rec) + "\n")
PY
}

load_scenario_or_die() {
  local scenario="$1" env_prefix="${2:-}" out rc
  out=$(dut_exec "env $env_prefix python3 /src/labs/hw/dut/load-scenario.py --scenario $scenario" 2>&1)
  rc=$?
  printf '%s\n' "$out" | tail -2
  if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -qE "Traceback|RuntimeError|failed:"; then
    echo "bench: loading scenario '$scenario' failed — refusing to benchmark a" >&2
    echo "  rule table that did not load. A partial load measures the wrong" >&2
    echo "  thing and would report PASS against almost no rules." >&2
    emit bench=load scenario="$scenario" verdict=FAIL detail="scenario did not load"
    exit 1
  fi
}

nic_rdma_raw() {
  $SSH "$DUT_SSH" "IFL='$SERVER_KERNEL_IFACE0' IFR='$SERVER_KERNEL_IFACE1' bash -s" 2>/dev/null <<'REMOTE'
ethtool -S "$IFL" | awk '$1 == "rx_packets_phy:" {rp = $2} $1 == "rx_prio0_buf_discard:" {pd = $2}
  $1 == "rx_out_of_buffer:" {ob = $2} END {printf "%d %d %d ", rp, pd, ob}'
ethtool -S "$IFR" | awk '$1 == "tx_packets_phy:" {printf "%d ", $2}'
cid=$(sg docker -c "docker ps -q --filter name=hw-dut" | head -1)
sg docker -c "docker exec $cid vppctl -s /run/vpp/cli.sock show interface eth-left" |
  awk '/rx packets/ {print $NF; exit}'
REMOTE
}

nic_snap() {
  if [ "${DUT_DRIVER:-dpdk}" = rdma ]; then
    nic_rdma_raw | awk '{print $1, $5}'
    return
  fi
  dut_exec "vppctl -s /run/vpp/cli.sock show hardware detail" 2>/dev/null |
    awk '/rx_phy_packets/ && !p {p=$2} /rx_good_packets/ && !g {g=$2}
         END {print (p?p:0), (g?g:0)}'
}
# The generator is pinned to an absolute packet rate (TREX_TARGET_MPPS in
# vars.sh, default 127 Mpps) rather than "100%" of whatever the generator card
# can push, so the offered load is identical on any generator and does not
# over-drive the link under test.  127 Mpps is the measured point below which
# the adapter contributes no load-dependent loss, so anything this gate reports
# above the ~0.43% floor is the DUT failing to keep up rather than the NIC
# saturating -- see docs/dut-throughput.csv for the sweep behind that number.
nic_lost_pct() {
  awk -v a="$1" -v b="$2" 'BEGIN{
    split(a,x," "); split(b,y," "); dp=y[1]-x[1]; dg=y[2]-x[2];
    printf "%.3f", (dp>0 ? (dp-dg)*100/dp : 0) }'
}

require_one_dut() {
  local n
  n="$($SSH "$DUT_SSH" 'sg docker -c "docker ps -q --filter name=hw-dut" | wc -l' 2>/dev/null || echo 0)"
  if [ "${n:-0}" -ne 1 ]; then
    echo "$1: expected exactly 1 DUT container, found ${n:-0}." >&2
    echo "  More than one VPP competes for CPU and inflates cyc/pkt; zero means" >&2
    echo "  the rig is not up.  Re-run labs/hw/bringup-guarded.sh." >&2
    exit 2
  fi
}

run_attack() {
  local arg="${1:-show}"
  if [ "$arg" = "show" ] || [ "$arg" = "list" ]; then
    echo "Valid attacks:"; for a in $VALID_ATTACKS; do echo "  $a"; done
    echo; echo "Usage: bench.sh attack <attack>|stop"
    return 0
  fi
  if [ "$arg" != "stop" ]; then
    local ok=0
    for a in $VALID_ATTACKS; do [ "$a" = "$arg" ] && ok=1; done
    if [ "$ok" = "0" ]; then
      echo "unknown attack: $arg" >&2; echo "valid: $VALID_ATTACKS" >&2; return 1
    fi
  fi
  local rate="${2:-}"
  if [ -z "$rate" ]; then
    for a in $MIXED_SIZE_ATTACKS; do
      [ "$a" = "$arg" ] && rate="${TREX_TARGET_GBPS_MIXED}gbps"
    done
  fi
  $SSH "$GEN_USER" \
    "CID=\$(docker ps -q --filter name=hw-gen); \
     [ -z \"\$CID\" ] && { echo 'generator TRex not running'; exit 1; }; \
     docker exec -e TREX_ATTACK='$arg' \"\$CID\" \
       python3 $GEN_CONF/switch.py '$arg' $rate"
}

cmd_oneport() {
  export LC_ALL=C
  local SCENARIOS="5rules-drop 0rules" ATTACK="fixed-flood-31" FLOOR=120
  local MAX_CYC_DROP="130" MAX_CYC_PASS="65" WARM_SEC=5 SAMPLE_SEC=10
  local MAX_NIC_LOST_PCT=1.0 OFFERED=""
  while [ $# -gt 0 ]; do case "$1" in
    --attack)       ATTACK="$2";       shift 2;;
    --floor)        FLOOR="$2";        shift 2;;
    --max-cyc-drop) MAX_CYC_DROP="$2"; shift 2;;
    --max-cyc-pass) MAX_CYC_PASS="$2"; shift 2;;
    --scenarios)    SCENARIOS="$2";    shift 2;;
    --offered)      OFFERED="$2";      shift 2;;
    --max-nic-lost) MAX_NIC_LOST_PCT="$2"; shift 2;;
    --warm)         WARM_SEC="$2";     shift 2;;
    --sample)       SAMPLE_SEC="$2";   shift 2;;
    *) echo "unknown arg: $1"; exit 1;;
  esac; done

  require_one_dut "one-port bench"

  echo ">> selecting attack profile: $ATTACK${OFFERED:+ at ${OFFERED} Mpps}"
  if [ -n "$OFFERED" ]; then
    run_attack "$ATTACK" "${OFFERED}mpps" 2>&1 | tail -3
  else
    run_attack "$ATTACK" 2>&1 | tail -3
  fi

  printf '\n%-14s  %9s  %9s  %9s  %14s  %14s  %s\n' \
    scenario "cyc/pkt" "DUT Mpps" "NIC lost" "filter vecs" "fwd-node vecs" verdict
  printf '%-14s  %9s  %9s  %9s  %14s  %14s  %s\n' \
    -------------- --------- --------- --------- -------------- -------------- -------

  local fail=0 scenario
  for scenario in $SCENARIOS; do
    load_scenario_or_die "$scenario" >/dev/null
    dut_exec "vppctl -s /run/vpp/cli.sock clear runtime" >/dev/null
        dut_exec "python3 /src/labs/hw/dut/fastacl-api.py clear-counters" >/dev/null
    sleep "$WARM_SEC"
    dut_exec "vppctl -s /run/vpp/cli.sock clear runtime" >/dev/null
    dut_exec "python3 /src/labs/hw/dut/fastacl-api.py clear-counters" >/dev/null
    local _nic0 _nic1 nic_lost; _nic0=$(nic_snap)
    sleep "$SAMPLE_SEC"
    local runtime; runtime=$(dut_exec "vppctl -s /run/vpp/cli.sock show runtime")
    _nic1=$(nic_snap); nic_lost=$(nic_lost_pct "$_nic0" "$_nic1")

    local filt_vec filt_cyc fwd_vec win mpps
    read -r filt_vec filt_cyc <<<"$(awk '/^fastacl-filter/ {v+=$4; c=$6} END{printf "%d %s", v, c}' <<<"$runtime")"
    fwd_vec=$(awk '/^(l2-output|ip4-lookup)/ {v+=$4} END{printf "%d", v}' <<<"$runtime")
    win=$(awk '/^Time /{sub(/,/,"",$2); print $2; exit}' <<<"$runtime")
    mpps=$(python3 -c "w=float('${win:-0}') or 1.0; print(f'{$filt_vec/w/1e6:.1f}')")

    local counters processed dropped cyc max_cyc
    counters=$(dut_exec "vppctl -s /run/vpp/cli.sock show fastacl aggregate-counters")
    processed=$(awk '/Processed:/{print $2}' <<<"$counters")
    dropped=$(awk '/Dropped:/{print $2}'   <<<"$counters")
    processed="${processed:-0}"; dropped="${dropped:-0}"; cyc="${filt_cyc:-n/a}"
    case "$scenario" in *drop) max_cyc="$MAX_CYC_DROP";; *) max_cyc="$MAX_CYC_PASS";; esac

    local verdict
    verdict=$(python3 - "$scenario" "$processed" "$dropped" "$filt_vec" "$fwd_vec" "$mpps" "$FLOOR" "$cyc" "$max_cyc" "$nic_lost" "$MAX_NIC_LOST_PCT" <<'PY'
import sys
scenario, processed, dropped, filt, fwd = (
    sys.argv[1], int(sys.argv[2] or 0), int(sys.argv[3] or 0),
    int(sys.argv[4] or 0), int(sys.argv[5] or 0))
mpps, floor = float(sys.argv[6] or 0), float(sys.argv[7] or 0)
cyc_s, max_cyc_s = sys.argv[8], sys.argv[9]
nic_lost, max_nic = float(sys.argv[10] or 0), float(sys.argv[11] or 0)
if processed == 0 or filt == 0:
    print("FAIL no-traffic"); sys.exit(0)
if mpps < floor:
    print(f"FAIL {mpps:.1f} Mpps below {floor:.0f} floor"); sys.exit(0)
# Peak held in software says nothing about what the adapter threw away first.
# Only meaningful where the filter drops: forwarding a 64 B packet costs more
# than dropping it, so the pass-through scenarios top out below 100 G (measured
# ~127 of 141 Mpps on the lab DUT) and shed the remainder at the adapter by
# design.  Those scenarios are a per-packet-cost baseline (--max-cyc-pass), not
# a line-rate claim, so the adapter gate applies to the dropping ones.
if max_nic and scenario.endswith("drop") and nic_lost > max_nic:
    print(f"FAIL adapter lost {nic_lost:.2f}% at peak (ceiling {max_nic:.1f}%)")
    sys.exit(0)
if max_cyc_s:
    try:
        cyc = float(cyc_s)
    except ValueError:
        print(f"FAIL cyc/pkt unreadable ({cyc_s!r})"); sys.exit(0)
    if cyc > float(max_cyc_s):
        print(f"FAIL {cyc:.0f} cyc/pkt over the {float(max_cyc_s):.0f} ceiling")
        sys.exit(0)
drop_ratio = dropped / processed
fwd_ratio = fwd / filt
if scenario.endswith("drop"):
    ok = drop_ratio > 0.99 and fwd_ratio < 0.01
    print("PASS dropped-in-node" if ok
          else f"FAIL {drop_ratio:.1%} dropped, {fwd_ratio:.1%} forwarded")
else:
    ok = drop_ratio < 0.01 and fwd_ratio > 0.99
    print("PASS forwarded-onward" if ok
          else f"FAIL {drop_ratio:.1%} dropped, only {fwd_ratio:.1%} forwarded")
PY
)
    printf '%-14s  %9s  %9s  %8s%%  %14s  %14s  %s\n' \
      "$scenario" "$cyc" "$mpps" "$nic_lost" "$filt_vec" "$fwd_vec" "$verdict"
    emit bench=oneport attack="$ATTACK" scenario="$scenario" offered_mpps="${OFFERED:-$TREX_TARGET_MPPS}" \
      dut_mpps="$mpps" nic_lost_pct="$nic_lost" cyc_pkt="$cyc" floor="$FLOOR" \
      max_cyc="$max_cyc" max_nic_lost_pct="$MAX_NIC_LOST_PCT" verdict="${verdict%% *}" \
      detail="$verdict"
    [[ "$verdict" == FAIL* ]] && fail=1
  done
  echo
  [ "$fail" -eq 0 ] && echo "one-port bench: all scenarios behaved as expected" \
                    || echo "one-port bench: FAILURES above"
  exit "$fail"
}

cmd_flows() {
  export LC_ALL=C
  local SCENARIO="1m-rules-drop" ATTACK="cold-scan" FLOWS=26000 MAX_CYC=330
  local ABSORB_MPPS=124 MAX_NIC_LOST_PCT=0.6
  local WARM_SEC=20 SAMPLE_SEC=30
  while [ $# -gt 0 ]; do case "$1" in
    --flows)    FLOWS="$2";      shift 2;;
    --max-cyc)  MAX_CYC="$2";    shift 2;;
    --warm)     WARM_SEC="$2";   shift 2;;
    --sample)   SAMPLE_SEC="$2"; shift 2;;
    --scenario) SCENARIO="$2";   shift 2;;
    --attack)   ATTACK="$2";     shift 2;;
    --absorb)   ABSORB_MPPS="$2"; shift 2;;
    --max-nic-lost) MAX_NIC_LOST_PCT="$2"; shift 2;;
    *) echo "unknown arg: $1"; exit 1;;
  esac; done

  echo "=== Working-set gate: $SCENARIO @ ${FLOWS} active flows ==="
  echo "    absorb >= ${ABSORB_MPPS} Mpps (DUT working-set throughput),"
  echo "    fastacl-filter <= ${MAX_CYC} cyc/pkt"; echo ""

  local trex_mpps dut_mpps cyc_pkt nic_lost
  read -r trex_mpps dut_mpps cyc_pkt nic_lost < <(sample_point "$SCENARIO" "$ATTACK" "$FLOWS" \
    "$WARM_SEC" "$SAMPLE_SEC")
  : "${trex_mpps:=-}" "${dut_mpps:=-}" "${cyc_pkt:=-}" "${nic_lost:=-}"

  if [ "$trex_mpps" = - ] || [ "$dut_mpps" = - ] || [ "$cyc_pkt" = - ]; then
    echo "FAIL: incomplete sample (trex='${trex_mpps:-}' dut='${dut_mpps:-}' cyc='${cyc_pkt:-}')"
    echo "      Refusing to pass on a measurement that did not happen."
    emit bench=flows scenario="$SCENARIO" attack="$ATTACK" flows="$FLOWS" verdict=FAIL \
      detail="incomplete sample"
    exit 2
  fi

  local need="$ABSORB_MPPS"
  echo ""
  printf '  offered      : %s Mpps (generator; over-provisions the DUT on purpose)\n' "$trex_mpps"
  printf '  absorbed     : %s Mpps (need >= %s)\n' "$dut_mpps" "$need"
  printf '  cyc/pkt      : %s (ceiling %s)\n' "$cyc_pkt" "$MAX_CYC"
  printf '  NIC lost     : %s%% of packets arriving at the port (ceiling %s%%)\n' \
    "$nic_lost" "$MAX_NIC_LOST_PCT"; echo ""

  local rc=0
  if awk -v d="$dut_mpps" -v n="$need" 'BEGIN{exit !(d < n)}'; then
    echo "FAIL: working set collapsed at $FLOWS flows — absorbed $dut_mpps Mpps (floor $need)."; rc=1
  else
    echo "PASS: DUT held $dut_mpps Mpps at $FLOWS active flows."
  fi
  if awk -v l="$nic_lost" -v m="$MAX_NIC_LOST_PCT" 'BEGIN{exit !(l > m)}'; then
    echo "FAIL: the adapter lost $nic_lost% of arriving packets (ceiling $MAX_NIC_LOST_PCT%)."
    echo "      Check rx_out_of_buffer / rx_phy_discard_packets in 'show hardware detail'."; rc=1
  else
    echo "PASS: adapter delivered $(awk -v l="$nic_lost" 'BEGIN{printf "%.2f", 100-l}')% of arriving packets."
  fi
  if awk -v c="$cyc_pkt" -v m="$MAX_CYC" 'BEGIN{exit !(c > m)}'; then
    echo "FAIL: $cyc_pkt cyc/pkt exceeds the $MAX_CYC ceiling."; rc=1
  else
    echo "PASS: per-packet cost within budget."
  fi
  emit bench=flows scenario="$SCENARIO" attack="$ATTACK" flows="$FLOWS" offered_mpps="$trex_mpps" \
    dut_mpps="$dut_mpps" nic_lost_pct="$nic_lost" cyc_pkt="$cyc_pkt" floor="$need" \
    max_cyc="$MAX_CYC" max_nic_lost_pct="$MAX_NIC_LOST_PCT" \
    verdict="$([ "$rc" = 0 ] && echo PASS || echo FAIL)"
  exit $rc
}

gen_alive() {
  [ "$($SSH "$GEN_USER" "CID=\$(docker ps -q --filter name=hw-gen | head -1); \
    [ -n \"\$CID\" ] && docker exec \$CID sh -c 'ps -o stat= -C _t-rex-64 | grep -q \"^[^Z]\"' && echo yes" \
    2>/dev/null)" = yes ]
}

gen_save_logs() {
  local dir; dir="$(dirname "$RESULTS_FILE")"; mkdir -p "$dir"
  $SSH "$GEN_USER" "for c in \$(docker ps -aq --filter name=hw-gen); do docker logs --tail 200 \$c 2>&1; done" \
    >"$dir/generator-$(date +%s).log" 2>/dev/null || true
}

sample_point() {
  local out
  gen_alive || { echo "sample_point: generator down, restarting it" >&2; gen_save_logs; gen_restart "${GEN_PKTSIZE:-64}" >&2; }
  out=$(sample_point_once "$@")
  case "$out" in
    "- "*|"")
      if ! gen_alive; then
        echo "sample_point: generator died during the sample, restarting and retrying" >&2
        gen_save_logs; gen_restart "${GEN_PKTSIZE:-64}" >&2 && out=$(sample_point_once "$@")
      fi ;;
  esac
  printf '%s\n' "$out"
}

sample_point_once() {
  local scenario="$1" attack="$2" flows="$3" warm="$4" sample="$5"
  load_scenario_or_die "$scenario" "FASTACL_TSWEEP_DECOYS=${FASTACL_TSWEEP_DECOYS:-0} ${SCENARIO_ENV:-}" >&2
  gen_exec "sh -c 'echo $flows > /tmp/cold-scan-flows'" >&2
  gen_exec "python3 $GEN_CONF/switch.py stop" >/dev/null
  sleep 3
  local _rate=""
  for a in $MIXED_SIZE_ATTACKS; do
    [ "$a" = "$attack" ] && _rate="${TREX_TARGET_GBPS_MIXED}gbps"
  done
  gen_exec "python3 $GEN_CONF/switch.py $attack $_rate" >/dev/null
  sleep 3

  local _trex_f _dut_f _nic0 _nic1; _trex_f=$(mktemp); _dut_f=$(mktemp)
  gen_exec "python3 $GEN_CONF/trex_sample.py $warm $sample 2>/dev/null" >"$_trex_f" &
  dut_exec "python3 /src/labs/hw/dut/attack_sample.py $warm $sample 2>/dev/null" >"$_dut_f" &
  sleep "$warm"
  _nic0=$(nic_snap)
  wait
  _nic1=$(nic_snap)
  local dut_line trex dut cyc lost
  dut_line=$(cat "$_dut_f"); trex=$(tr -d ' \r\n' <"$_trex_f")
  dut=$(echo "$dut_line" | awk '{print $2}'); cyc=$(echo "$dut_line" | awk '{print $1}')
  lost=$(nic_lost_pct "$_nic0" "$_nic1")
  printf '%s %s %s %s\n' "${trex:--}" "${dut:--}" "${cyc:--}" "${lost:--}"
  rm -f "$_trex_f" "$_dut_f"
}

cmd_survey() {
  export LC_ALL=C
  local SCENARIOS="5rules-drop 1m-rules-drop" ATTACKS="" FLOWS_LIST="26000" WARM_SEC=10 SAMPLE_SEC=15
  local SWEEP="attacks" NRULES_LIST=""
  while [ $# -gt 0 ]; do case "$1" in
    --scenarios) SCENARIOS="$2";  shift 2;;
    --attacks)   ATTACKS="$2";    shift 2;;
    --flows)     FLOWS_LIST="$2"; shift 2;;
    --warm)      WARM_SEC="$2";   shift 2;;
    --sample)    SAMPLE_SEC="$2"; shift 2;;
    --sweep)     SWEEP="$2";      shift 2;;
    --nrules)    NRULES_LIST="$2"; SCENARIOS="nrules-drop"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac; done
  [ -n "$ATTACKS" ] || ATTACKS=$(python3 - "$SCRIPT_DIR/gen/conf/attacks.py" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
block = src[src.index("PROFILES = {"):]
block = block[:block.index("}")]
print(" ".join(re.findall(r'"([a-z0-9-]+)":', block)))
PY
)
  [ -n "$ATTACKS" ] || { echo "survey: no attack profiles found" >&2; exit 2; }

  require_one_dut "survey"
  printf '%-20s  %-24s  %8s  %9s  %9s  %8s  %8s\n' scenario attack flows offered absorbed "cyc/pkt" "lost%"
  local scenario attack flows nrules
  for nrules in ${NRULES_LIST:--}; do
    for scenario in $SCENARIOS; do
      for attack in $ATTACKS; do
        for flows in $FLOWS_LIST; do
          local trex_mpps dut_mpps cyc_pkt nic_lost
          [ "$nrules" = - ] && SCENARIO_ENV="" || SCENARIO_ENV="FASTACL_NRULES=$nrules"
          read -r trex_mpps dut_mpps cyc_pkt nic_lost < <(sample_point "$scenario" "$attack" \
            "$flows" "$WARM_SEC" "$SAMPLE_SEC")
          printf '%-20s  %-24s  %8s  %9s  %9s  %8s  %8s\n' "$scenario" "$attack" "$flows" \
            "${trex_mpps:--}" "${dut_mpps:--}" "${cyc_pkt:--}" "${nic_lost:--}"
          emit bench=survey sweep="$SWEEP" scenario="$scenario" attack="$attack" flows="$flows" \
            nrules="${nrules#-}" offered_mpps="${trex_mpps:-}" dut_mpps="${dut_mpps:-}" \
            cyc_pkt="${cyc_pkt:-}" nic_lost_pct="${nic_lost:-}" verdict=INFO
        done
      done
    done
  done
  SCENARIO_ENV=""
}

gen_restart() {
  local size="$1" mpps="$TREX_TARGET_MPPS"
  [ "$size" -gt 64 ] && mpps=0
  GEN_PKTSIZE="$size"
  $SSH "$GEN_USER" "sg docker -c 'docker ps -aq --filter name=hw-gen | xargs -r docker rm -f' >/dev/null 2>&1
    cd ~/${HOST_REPO:-fastacl-testbench} && GEN='$GEN' DUT='$DUT' GEN_DOCKERFILE='${GEN_DOCKERFILE:-docker/Dockerfile.trex}' GEN_IMAGE='${GEN_IMAGE:-hw-gen}' TREX_PKTSIZE='$size' \
      TREX_TARGET_MPPS='$mpps' sg docker -c 'docker compose -f labs/hw/compose.yaml run -d gen'" \
    >/dev/null 2>&1
  local i up=""
  for i in $(seq 1 12); do
    sleep 10
    gen_alive && { up=yes; break; }
  done
  [ "$up" = yes ] || { echo "gen_restart: TRex did not come back at ${size} B" >&2; return 1; }
  sleep 15
}

cmd_frames() {
  export LC_ALL=C
  local SIZES="64 128 256 512 1024 1500" ATTACK="fixed-flood-31" WARM_SEC=10 SAMPLE_SEC=15
  while [ $# -gt 0 ]; do case "$1" in
    --sizes)  SIZES="$2";  shift 2;;
    --attack) ATTACK="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac; done
  require_one_dut "frames"
  printf '%-8s  %-12s  %9s  %9s  %8s  %8s\n' frame scenario offered absorbed "cyc/pkt" "lost%"
  local size scenario
  for size in $SIZES; do
    gen_restart "$size" || { emit bench=frames frame="$size" verdict=FAIL detail="generator restart failed"; continue; }
    for scenario in 5rules-drop 0rules; do
      local trex_mpps dut_mpps cyc_pkt nic_lost
      read -r trex_mpps dut_mpps cyc_pkt nic_lost < <(sample_point "$scenario" "$ATTACK" 0 \
        "$WARM_SEC" "$SAMPLE_SEC")
      printf '%-8s  %-12s  %9s  %9s  %8s  %8s\n' "$size" "$scenario" "$trex_mpps" "$dut_mpps" \
        "$cyc_pkt" "$nic_lost"
      emit bench=survey sweep=frames frame="$size" scenario="$scenario" attack="$ATTACK" \
        offered_mpps="${trex_mpps:-}" dut_mpps="${dut_mpps:-}" cyc_pkt="${cyc_pkt:-}" \
        nic_lost_pct="${nic_lost:-}" verdict=INFO
    done
  done
  gen_restart 64
  for scenario in 5rules-drop 0rules; do
    local trex_mpps dut_mpps cyc_pkt nic_lost
    read -r trex_mpps dut_mpps cyc_pkt nic_lost < <(sample_point "$scenario" cold-scan-imix 1000 \
      "$WARM_SEC" "$SAMPLE_SEC")
    emit bench=survey sweep=frames frame=imix scenario="$scenario" attack=cold-scan-imix \
      offered_mpps="${trex_mpps:-}" dut_mpps="${dut_mpps:-}" cyc_pkt="${cyc_pkt:-}" \
      nic_lost_pct="${nic_lost:-}" verdict=INFO
  done
}

cmd_psample() {
  local ATTACK="fixed-flood-31" RATIO=1048576 GROUP=7
  while [ $# -gt 0 ]; do case "$1" in
    --attack) ATTACK="$2"; shift 2;;
    --ratio)  RATIO="$2";  shift 2;;
    --group)  GROUP="$2";  shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac; done

  require_one_dut "psample bench"
  cleanup() { run_attack stop >/dev/null 2>&1 || true; }
  trap cleanup EXIT

  echo ">> starting flood: $ATTACK"
  run_attack "$ATTACK" 2>&1 | tail -3

  echo ">> running DUT psample check (ratio 1:$RATIO group $GROUP)"
  dut_exec "python3 /src/labs/hw/dut/action_check.py psample --ratio $RATIO --group $GROUP"
  local rc=$?
  if [ "$rc" = 0 ]; then
    echo "PASS: psample delivered samples under $ATTACK with 0 send failures"
    emit bench=psample attack="$ATTACK" verdict=PASS
  else
    echo "FAIL: psample check exited $rc" >&2
    emit bench=psample attack="$ATTACK" verdict=FAIL detail="exit $rc"
  fi
  exit $rc
}

# Per-interface counter snapshot.  `show hardware detail` prints one block per
# interface, so track which block a counter belongs to rather than taking the
# first match -- ingress and egress carry the same counter names.
nic_snap_pair() {
  if [ "${DUT_DRIVER:-dpdk}" = rdma ]; then
    nic_rdma_raw | awk '{print $1, $5, $2, $3, $4}'
    return
  fi
  dut_exec "vppctl -s /run/vpp/cli.sock show hardware detail" 2>/dev/null |
    awk -v L=eth-left -v R=eth-right '
      { sub(/\r$/, "") }        # vppctl over ssh emits CRLF
      /^[^ \t]/ && NF { iface=$1; next }
      iface==L && $1=="rx_phy_packets"               { rp=$2 }
      iface==L && $1=="rx_good_packets"              { rg=$2 }
      iface==L && $1=="rx_prio0_buf_discard_packets" { pd=$2 }
      iface==L && $1=="rx_out_of_buffer"             { ob=$2 }
      iface==R && $1=="tx_phy_packets"               { tx=$2 }
      END { print (rp?rp:0), (rg?rg:0), (pd?pd:0), (ob?ob:0), (tx?tx:0) }'
}

# Is the forward-path ceiling a shared NIC/IO *transaction* budget, or is RX
# limited on its own?  Hold the offered load constant and vary only how much the
# rules DROP: dropping N of the 3 spread targets removes N/3 of the EGRESS
# transactions while ingress is untouched.
#
#   shared budget  => RX_in + TX_out stays CONSTANT while RX_in rises as TX falls
#   RX-limited     => RX_in does not move when TX load is removed
#
# The two are mutually exclusive, so the run decides it either way.  Targets
# mirror SPREAD_TARGETS in gen/conf/attacks.py.
cmd_ceiling() {
  export LC_ALL=C
  local ATTACK="fixed-flood-31" SAMPLE_SEC=15 WARM_SEC=5
  while [ $# -gt 0 ]; do case "$1" in
    --attack) ATTACK="$2"; shift 2;;
    --sample) SAMPLE_SEC="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac; done
  local TARGETS="10.0.2.1 198.51.100.1 192.0.2.1"

  require_one_dut "ceiling proof"
  echo ">> selecting attack profile: $ATTACK"
  run_attack "$ATTACK" 2>&1 | tail -2

  printf '\n%-16s  %8s  %8s  %8s  %9s  %7s  %8s  %s\n' \
    "rules drop" offered RX_in TX_out "RX+TX" lost "prio0" out_of_buf
  printf '%-16s  %8s  %8s  %8s  %9s  %7s  %8s  %s\n' \
    ---------------- -------- -------- -------- --------- ------- -------- ----------

  local n
  for n in 0 1 2 3; do
    load_scenario_or_die 0rules >/dev/null
    local k=0 t
    for t in $TARGETS; do
      [ "$k" -ge "$n" ] && break
      dut_exec "python3 /src/labs/hw/dut/fastacl-api.py rule-add $((10+k)) $t/32 17" >/dev/null
      k=$((k+1))
    done
    sleep "$WARM_SEC"
    local s0 s1 t0 t1
    s0=$(nic_snap_pair); t0=$(date +%s.%N)
    sleep "$SAMPLE_SEC"
    s1=$(nic_snap_pair); t1=$(date +%s.%N)
    mkdir -p "$(dirname "$RESULTS_FILE")"
    RESULTS_FILE="$RESULTS_FILE" python3 - "$n" "$t0" "$t1" $s0 $s1 <<'PY'
import sys
n = int(sys.argv[1]); el = float(sys.argv[3]) - float(sys.argv[2])
a = [int(x) for x in sys.argv[4:9]]
b = [int(x) for x in sys.argv[9:14]]
rp, rg, pd, ob, tx = (y - x for x, y in zip(a, b))
if rp <= 0 or el <= 0:
    print(f"  {'%d/3'%n:<16}  NO TRAFFIC (rx_phy delta={rp})"); sys.exit(0)
lost = rp - rg
import json, os, time
with open(os.environ["RESULTS_FILE"], "a") as f:
    f.write(json.dumps({"ts": int(time.time()), "dut": os.environ.get("DUT_PROFILE", os.environ.get("PROFILE", "")),
                        "gen": os.environ.get("GEN", ""), "bench": "ceiling",
                        "scenario": f"drop {n}/3", "offered_mpps": round(rp / el / 1e6, 2),
                        "dut_mpps": round(rg / el / 1e6, 2), "tx_mpps": round(tx / el / 1e6, 2),
                        "nic_lost_pct": round(lost * 100 / rp, 3), "verdict": "INFO"}) + "\n")
print(f"  {'%d/3'%n:<16}  {rp/el/1e6:8.1f}  {rg/el/1e6:8.1f}  {tx/el/1e6:8.1f}  "
      f"{(rg+tx)/el/1e6:9.1f}  {lost*100/rp:6.2f}%  "
      f"{pd*100/lost if lost else 0:7.1f}%  {ob}")
PY
  done
  dut_exec "python3 /src/labs/hw/dut/fastacl-api.py del-all" >/dev/null
  echo ""
  echo "  RX+TX flat across rows => shared NIC/IO transaction ceiling (that value)."
  echo "  RX_in flat instead     => ingress is limited independently of egress."
}

# Structural gate for named prefix sets.  A throughput check alone would not
# catch a regression that put set membership back into the tuple mask: on a
# fast box the rate can still pass while every packet quietly probes one tuple
# per prefix length again.  Assert the tuple count directly.
cmd_sets_tuples() {
  export LC_ALL=C
  local SCENARIO="country-set-drop" MAX_TUPLES=1
  while [ $# -gt 0 ]; do case "$1" in
    --scenario)   SCENARIO="$2";   shift 2;;
    --max-tuples) MAX_TUPLES="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac; done

  require_one_dut "sets-tuples"
  load_scenario_or_die "$SCENARIO"

  local n
  n=$(dut_exec "vppctl -s /run/vpp/cli.sock show fastacl tuples" 2>/dev/null |
      tr -d '\r' | awk -F: '/^tuples:/ {gsub(/ /,"",$2); print $2; exit}')
  local sets
  sets=$(dut_exec "vppctl -s /run/vpp/cli.sock show fastacl sets" 2>/dev/null |
         tr -d '\r' | tail -1)

  echo "  sets row : $sets"
  echo "  tuples   : ${n:-?} (ceiling $MAX_TUPLES)"

  if [ -z "$n" ]; then
    emit bench=sets-tuples scenario="$SCENARIO" verdict=FAIL detail="tuple count unreadable"
    echo "FAIL: could not read tuple count" >&2
    exit 1
  fi
  emit bench=sets-tuples scenario="$SCENARIO" tuples="$n" max_tuples="$MAX_TUPLES" \
    verdict="$([ "$n" -le "$MAX_TUPLES" ] && echo PASS || echo FAIL)"
  if [ "$n" -gt "$MAX_TUPLES" ]; then
    echo "FAIL: $SCENARIO produced $n tuples, ceiling is $MAX_TUPLES --" >&2
    echo "  set membership has leaked back into the tuple mask." >&2
    exit 1
  fi
  echo "PASS: $SCENARIO holds at $n tuple(s) regardless of prefix-length spread."
}

host_exec() { $SSH "$1" "$2" 2>/dev/null | tr -d '\r'; }

cmd_rig() {
  require_one_dut "rig"
  local vppctl="vppctl -s /run/vpp/cli.sock"
  local dut_cpu dut_cores dut_kernel dut_os dut_nic gen_cpu gen_cores gen_nic vpp_ver plugin_ver
  local workers link lic_kind lic_expires
  dut_cpu=$(host_exec "$DUT_SSH" "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs")
  dut_cores=$(host_exec "$DUT_SSH" "grep -c ^processor /proc/cpuinfo")
  dut_kernel=$(host_exec "$DUT_SSH" "uname -r")
  dut_os=$(host_exec "$DUT_SSH" "P=$DUT_PCI_LEFT; . /etc/os-release
    i=\$(ls /sys/bus/pci/devices/\$P/net 2>/dev/null | head -1)
    fw=\$(cat /sys/bus/pci/devices/\$P/infiniband/*/fw_ver 2>/dev/null | head -1)
    [ -n \"\$fw\" ] || fw=\$(ethtool -i \"\$i\" 2>/dev/null | awk '/^firmware-version/{print \$2}')
    echo \"\$PRETTY_NAME, NIC firmware \$fw\"")
  dut_nic=$(host_exec "$DUT_SSH" "lspci -s ${DUT_PCI_LEFT#0000:} | cut -d: -f3- | xargs")
  gen_cpu=$(host_exec "$GEN_USER" "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs")
  gen_cores=$(host_exec "$GEN_USER" "grep -c ^processor /proc/cpuinfo")
  gen_nic=$(host_exec "$GEN_USER" "lspci -s ${SENDER_PCI#0000:} | cut -d: -f3- | xargs")
  vpp_ver=$(dut_exec "$vppctl show version" 2>/dev/null | tr -d '\r' | awk '{print $2}' | head -1)
  plugin_ver=$(dut_exec "dpkg-query -W fastacl-plugin" 2>/dev/null | tr -d '\r' | awk '{print $2}')
  workers=$(dut_exec "$vppctl show threads" 2>/dev/null | grep -c vpp_wk_)
  link=$(dut_exec "$vppctl show hardware-interfaces eth-left" 2>/dev/null |
         awk -F': ' '/Link speed/{print $2; exit}' | tr -d '\r')
  lic_kind=$(dut_exec "$vppctl show fastacl license" 2>/dev/null | awk -F': *' '/^kind/{print $2}' | tr -d '\r')
  lic_expires=$(dut_exec "$vppctl show fastacl license" 2>/dev/null |
                awk -F': *' '/^expires/{print $2}' | tr -d '\r')
  emit bench=rig dut_cpu="$dut_cpu" dut_cores="$dut_cores" dut_kernel="$dut_kernel" dut_os="$dut_os" \
    dut_nic="$dut_nic" link_speed="$link" gen_cpu="$gen_cpu" gen_cores="$gen_cores" \
    gen_nic="$gen_nic" vpp_version="$vpp_ver" plugin_version="$plugin_ver" \
    vpp_workers="$workers" rx_desc="$DUT_RX_DESC" tx_desc="$DUT_TX_DESC" \
    trex_version="${TREX_VERSION:-3.06}" target_mpps="$TREX_TARGET_MPPS" \
    target_gbps_mixed="$TREX_TARGET_GBPS_MIXED" licence="$lic_kind" licence_expires="$lic_expires" \
    dut_driver="$([ "${DUT_DRIVER:-dpdk}" = rdma ] && echo "rdma ${DUT_RDMA_MODE:-dv}" || echo dpdk)" \
    verdict=INFO
  printf '%-18s %s\n' DUT "$dut_cpu ($dut_cores CPUs), $dut_nic, $link, kernel $dut_kernel" \
    generator "$gen_cpu ($gen_cores CPUs), $gen_nic" VPP "$vpp_ver, $workers workers" \
    FastACL "$plugin_ver, licence $lic_kind until $lic_expires"
}

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  attack)  run_attack "$@";;
  oneport) cmd_oneport "$@";;
  flows)   cmd_flows "$@";;
  psample) cmd_psample "$@";;
  ceiling) cmd_ceiling "$@";;
  sets-tuples) cmd_sets_tuples "$@";;
  survey)  cmd_survey "$@";;
  rig)     cmd_rig "$@";;
  frames)  cmd_frames "$@";;
  ""|-h|--help|help) usage;;
  *) echo "unknown subcommand: $cmd" >&2; usage; exit 2;;
esac
