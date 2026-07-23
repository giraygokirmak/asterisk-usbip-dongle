#!/bin/bash
set -uo pipefail
VENDOR_ID="${USBIP_VENDOR_ID:-12d1}"; COMMAND_TIMEOUT="${USBIP_COMMAND_TIMEOUT:-10}"; AUTO_RECOVER="${USBIP_AUTO_RECOVER_STALE:-0}"
log(){ echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }; run_usbip(){ timeout -k 5 "$COMMAND_TIMEOUT" usbip "$@"; }
find_busids(){ run_usbip list -l 2>/dev/null|awk -v v="$VENDOR_ID:" '/busid/{b=$3;gsub(/[(),]/,"",b)} index(tolower($0),v)&&b!=""{print b;b=""}'|sort -u; }
bind_one(){ local b=$1 s; if [[ -e /sys/bus/usb/drivers/usbip-host/$b ]]; then s=$(cat "/sys/bus/usb/drivers/usbip-host/$b/usbip_status" 2>/dev/null||echo unknown); log "$b already bound (usbip_status=$s)"; if [[ $AUTO_RECOVER == 1 && $s == 2 ]]; then USBIP_VENDOR_ID="$VENDOR_ID" USBIP_COMMAND_TIMEOUT="$COMMAND_TIMEOUT" /usr/local/sbin/usbip-huawei-recover --auto "$b"; fi; return; fi; log "Binding Huawei device $b"; run_usbip bind -b "$b"; }
main(){ pgrep -x usbipd >/dev/null||{ log "ERROR: usbipd is not running";return 1;}; busids=$(find_busids); [[ -n $busids ]]||{ log "No Huawei devices detected";return 0;}; failures=0; while read -r b;do [[ -z $b ]]||bind_one "$b"||failures=$((failures+1));done<<<"$busids"; [[ $failures -eq 0 ]]; }
main "$@"
