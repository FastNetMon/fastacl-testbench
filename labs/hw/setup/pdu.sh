#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

CMD="${1:-status}"

resolve() {
  local tgt="$1" spec
  case "$tgt" in
    pdu1:*|pdu2:*) spec="$tgt" ;;
    *) local v="PDU_MAP_${tgt}"; spec="${!v:-}"
       [ -n "$spec" ] || { echo "unknown machine '$tgt' (add PDU_MAP_$tgt to vars.sh)" >&2; exit 1; } ;;
  esac
  PDU="${spec%%:*}"; OUTLET="${spec##*:}"
  case "$PDU" in
    pdu1) HOST="$PDU1_HOST"; PASS="$PDU1_PASS" ;;
    pdu2) HOST="$PDU2_HOST"; PASS="$PDU2_PASS" ;;
    *) echo "bad pdu '$PDU'"; exit 1 ;;
  esac
  [ "${OUTLET:-0}" != "0" ] || { echo "outlet for '$tgt' is unset in vars.sh (PDU_MAP_$tgt) — fill it in first" >&2; exit 1; }
  TOKEN="$(printf '%s:%s' "$PDU_USER" "$PASS" | base64)"
}

pdu_curl() {
  ssh $SSH_OPTS "$PDU_PROXY" \
    "curl -sS -m8 -X POST 'http://$HOST/$1' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -H 'Authorization: $TOKEN' --data '$2'"
}

status() {
  local which="${1:-pdu1}"; resolve "$which:1" >/dev/null 2>&1 || { PDU="$which"; case "$which" in pdu1) HOST=$PDU1_HOST PASS=$PDU1_PASS;; pdu2) HOST=$PDU2_HOST PASS=$PDU2_PASS;; esac; TOKEN="$(printf '%s:%s' "$PDU_USER" "$PASS" | base64)"; }
  echo "=== $which ($HOST) ==="
  pdu_curl "4.js" '{"pdu_id":0}' | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception as e: print("  (parse error:",e,")"); sys.exit()
for s in d.get("data",[]):
    alias,state=s["value"][0] or "-", ("ON " if str(s["value"][1])=="1" else "off")
    print(f"  outlet {s[\"id\"]:>2}  [{state}]  {alias}")'
}

control() {
  local action="$1" tgt="$2"; shift 2 || true
  local yes=0; for a in "$@"; do [ "$a" = "--yes" ] && yes=1; done
  resolve "$tgt"
  local value; [ "$action" = on ] && value=1 || value=0
  local info; info=$(pdu_curl "4.js" '{"pdu_id":0}' | python3 -c "
import sys,json; d=json.load(sys.stdin)
for s in d.get('data',[]):
    if s['id']==$OUTLET: print((s['value'][0] or '-'), '1' if str(s['value'][1])=='1' else '0')" 2>/dev/null)
  local alias="${info% *}" cur="${info##* }"
  echo "$PDU outlet $OUTLET  (alias: ${alias:-ّ-})  currently: $([ "$cur" = 1 ] && echo ON || echo off)  ->  $action"
  if [ "$action" = off ] && [ "$yes" != 1 ]; then
    echo "refusing to power OFF without --yes (outlet $OUTLET on $PDU may carry live gear)"; exit 1
  fi
  pdu_curl "set_socket_open.js" "{\"id\":$OUTLET,\"value\":$value,\"pdu_id\":0}" >/dev/null
  echo "  done ($action)"
}

case "$CMD" in
  status)  status "${2:-pdu1}" ;;
  on)      control on  "${2:?machine}" "${@:3}" ;;
  off)     control off "${2:?machine}" "${@:3}" ;;
  cycle)   control off "${2:?machine}" --yes; echo "  waiting 5s…"; sleep 5; control on "${2}" ;;
  *) echo "usage: $0 {status [pdu1|pdu2] | on <m> | off <m> --yes | cycle <m> --yes}"; exit 1 ;;
esac
