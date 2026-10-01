#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

TARGET="${IPMI_TARGET:-dut}"
if [ "${1:-}" = "--target" ] || [ "${1:-}" = "-t" ]; then
  TARGET="${2:?--target needs a name (dut|dell)}"; shift 2
fi
case "$TARGET" in
  dut)  BMC_HOST="$DUT_IPMI_HOST";   BMC_USER="$DUT_IPMI_USER";   BMC_PASS="$DUT_IPMI_PASS";   BMC_NAME="DUT (${DUT_HOST%%.*})"; BMC_PROTO="ipmi" ;;
  dell) BMC_HOST="$DELL_IDRAC_HOST"; BMC_USER="$DELL_IDRAC_USER"; BMC_PASS="$DELL_IDRAC_PASS"; BMC_NAME="dell (iDrac, R740)"; BMC_PROTO="redfish" ;;
  *) echo "unknown target: $TARGET (use dut|dell)"; exit 1 ;;
esac

CMD="${1:-status}"

IPMI_PROXY="${IPMI_PROXY:-${LAB_PROXY:-}}"

_ipmi() {
  if command -v ipmitool &>/dev/null && ping -c1 -W1 "$BMC_HOST" &>/dev/null; then
    ipmitool -I lanplus -H "$BMC_HOST" -U "$BMC_USER" -P "$BMC_PASS" "$@"
  else
    echo "(BMC not directly reachable — proxying through $IPMI_PROXY)"
    ssh -o ConnectTimeout=10 "$IPMI_PROXY" \
      "command -v ipmitool &>/dev/null || sudo apt-get install -y -q ipmitool >/dev/null 2>&1
       ipmitool -I lanplus -H '$BMC_HOST' -U '$BMC_USER' -P '$BMC_PASS' $*"
  fi
}

_redfish() {
  local method="$1" path="$2" body="${3:-}"
  local cl=(-sk -u "$BMC_USER:$BMC_PASS" -X "$method" --connect-timeout 8)
  [ -n "$body" ] && cl+=(-H "Content-Type: application/json" -d "$body")
  if command -v curl &>/dev/null && ping -c1 -W1 "$BMC_HOST" &>/dev/null; then
    curl "${cl[@]}" "https://$BMC_HOST$path"
  else
    ssh -o ConnectTimeout=10 "$IPMI_PROXY" \
      "curl -sk -u '$BMC_USER:$BMC_PASS' -X $method --connect-timeout 8 ${body:+-H 'Content-Type: application/json' -d '$body'} 'https://$BMC_HOST$path'"
  fi
}
RF_SYS="/redfish/v1/Systems/System.Embedded.1"
_rf_reset() { _redfish POST "$RF_SYS/Actions/ComputerSystem.Reset" "{\"ResetType\":\"$1\"}" >/dev/null && echo "  Redfish reset: $1 sent"; }
_rf_status() {
  _redfish GET "$RF_SYS" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("  PowerState:",d.get("PowerState"),"| Model:",d.get("Model"),"| BIOS:",d.get("BiosVersion"))' 2>/dev/null \
    || echo "  (could not parse Redfish response)"
}

_power() {
  if [ "$BMC_PROTO" = "redfish" ]; then
    case "$1" in
      status) _rf_status ;;
      on)     _rf_reset On ;;
      off)    _rf_reset ForceOff ;;
      cycle)  _rf_reset ForceOff
              for _ in $(seq 1 20); do _rf_status | grep -qi "off" && break; sleep 2; done
              sleep 5
              for _ in $(seq 1 3); do
                _rf_reset On
                sleep 6
                _rf_status | grep -qi "on" && break
              done ;;
      reset)  _rf_reset ForceRestart ;;
    esac
  else
    case "$1" in
      status) _ipmi power status ;;
      on)     _ipmi power on ;;
      off)    _ipmi power off ;;
      # A fixed 3 s gap was not enough: the BMC can still be powering the
      # chassis down when "on" arrives, drops it silently, and leaves the host
      # dark -- the worst outcome for an unattended recovery, because the rig
      # looks wedged rather than off.  Wait for the off state to settle, then
      # power on and confirm it actually stuck.
      cycle)  _ipmi power off 2>/dev/null || true
              for _ in $(seq 1 20); do
                _ipmi power status 2>/dev/null | grep -qi "is off" && break
                sleep 2
              done
              sleep 5
              for _ in $(seq 1 3); do
                _ipmi power on 2>/dev/null || true
                sleep 6
                _ipmi power status 2>/dev/null | grep -qi "is on" && break
              done ;;
      reset)  _ipmi power reset ;;
    esac
  fi
}

case "$CMD" in
  status)
    echo "=== $BMC_NAME power status ($BMC_HOST) ==="
    _power status
    ;;
  reset)
    echo "=== $BMC_NAME chassis reset ($BMC_HOST) ==="
    _power reset
    echo "Reset command sent.  $BMC_NAME will reboot in ~30 s."
    ;;
  cycle)
    echo "=== $BMC_NAME hard power-cycle ($BMC_HOST) ==="
    _power cycle
    if _power status 2>/dev/null | grep -qi "is on\|: on"; then
      echo "Power-cycle complete.  $BMC_NAME booting..."
    else
      echo "WARNING: $BMC_NAME is still OFF after the cycle -- the BMC dropped" >&2
      echo "  the power-on.  Retry with: $0 --target $TARGET on" >&2
      exit 1
    fi
    ;;
  off)
    echo "=== $BMC_NAME power off ($BMC_HOST) ==="
    _power off
    ;;
  on)
    echo "=== $BMC_NAME power on ($BMC_HOST) ==="
    _power on
    ;;
  sol)
    if [ "$BMC_PROTO" = "redfish" ]; then
      echo "SOL not wired over Redfish for $BMC_NAME — use the Virtual Console at https://$BMC_HOST"
    else
      echo "Opening Serial-over-LAN console (press Ctrl-] to exit)..."
      _ipmi sol activate
    fi
    ;;
  sensors)
    if [ "$BMC_PROTO" = "redfish" ]; then
      echo "=== $BMC_NAME thermal (Redfish) ==="
      _redfish GET "/redfish/v1/Chassis/System.Embedded.1/Thermal" \
        | python3 -c 'import sys,json;d=json.load(sys.stdin); [print("  %-28s %s C"%(t.get("Name"),t.get("ReadingCelsius"))) for t in d.get("Temperatures",[]) if t.get("ReadingCelsius") is not None]' 2>/dev/null \
        || echo "  (could not parse Redfish thermal)"
    else
      _ipmi sdr type Temperature
      _ipmi sdr type Fan
      _ipmi sdr type Voltage
    fi
    ;;
  *)
    echo "Usage: $0 [--target dut|dell] {status|reset|cycle|off|on|sol|sensors}"
    exit 1
    ;;
esac
