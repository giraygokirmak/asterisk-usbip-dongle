#!/bin/bash
set -euo pipefail
VENDOR_ID="${USBIP_VENDOR_ID:-12d1}"
COMMAND_TIMEOUT="${USBIP_COMMAND_TIMEOUT:-10}"
STALL_WINDOW="${USBIP_STALL_WINDOW:-120 seconds ago}"
SYSFS_ROOT="${SYSFS_ROOT:-/sys}"
STALL_THRESHOLD="${USBIP_STALL_THRESHOLD:-20}"
COOLDOWN="${USBIP_RECOVERY_COOLDOWN:-300}"
STATE_DIR="${USBIP_STATE_DIR:-/run/usbip-huawei}"
LOCK_FILE="$STATE_DIR/recovery.lock"
LAST_FILE="$STATE_DIR/last-recovery"
log(){ echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }
run_usbip(){ timeout -k 5 "$COMMAND_TIMEOUT" usbip "$@"; }
usage(){ echo "Usage: $0 [--auto] BUSID" >&2; exit 2; }
mode=manual
[[ ${1:-} == --auto ]]&&{ mode=auto;shift; }
busid=${1:-}; [[ -n $busid ]]||usage
[[ $busid =~ ^[0-9]+-[0-9.]+$ ]]||usage
mkdir -p "$STATE_DIR"; exec 9>"$LOCK_FILE"; flock -n 9||{ log "Another recovery is running"; exit 0; }
device="$SYSFS_ROOT/bus/usb/devices/$busid"
[[ -r "$device/idVendor" ]]||{ log "ERROR: device $busid is absent"; exit 1; }
[[ $(tr '[:upper:]' '[:lower:]' <"$device/idVendor") == "$VENDOR_ID" ]]||{ log "ERROR: refusing non-Huawei device $busid"; exit 1; }
if [[ $mode == auto ]]; then
  now=$(date +%s); last=$(cat "$LAST_FILE" 2>/dev/null||echo 0); (( now-last >= COOLDOWN ))||{ log "Recovery cooldown active"; exit 0; }
  status=$(cat "$SYSFS_ROOT/bus/usb/drivers/usbip-host/$busid/usbip_status" 2>/dev/null||echo 0)
  [[ $status == 2 ]]||exit 0
  stalls=$(journalctl -k --since "$STALL_WINDOW" --no-pager 2>/dev/null|grep -F "usbip-host $busid: endpoint"|grep -c 'is stalled' || true)
  (( stalls >= STALL_THRESHOLD ))||{ log "$busid is in use; only $stalls stalls observed, leaving it untouched"; exit 0; }
  log "Automatic recovery threshold reached: $stalls stalls"
fi
log "Recovering Huawei USB/IP device $busid"
run_usbip unbind -b "$busid" 2>/dev/null||true
sleep 2
run_usbip bind -b "$busid"
status=$(cat "$SYSFS_ROOT/bus/usb/drivers/usbip-host/$busid/usbip_status" 2>/dev/null||echo missing)
[[ $status == 1 ]]||{ log "ERROR: expected usbip_status=1, got $status"; exit 1; }
run_usbip list -r 127.0.0.1|grep -q "$busid"||{ log "ERROR: $busid is not exportable after recovery"; exit 1; }
date +%s >"$LAST_FILE"; log "$busid recovered and exportable"
