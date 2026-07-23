#!/bin/sh
set -u
USB_IP=$(printf '%s' "${USB_IP:-}" | tr -d '\r\n ')
USBIP_VENDOR_ID=$(printf '%s' "${USBIP_VENDOR_ID:-12d1}" | tr '[:upper:]' '[:lower:]')
USBIP_MIN_DEVICES=${USBIP_MIN_DEVICES:-1}; USBIP_COMMAND_TIMEOUT=${USBIP_COMMAND_TIMEOUT:-10}
USBIP_RETRY_INITIAL=${USBIP_RETRY_INITIAL:-10}; USBIP_RETRY_MAX=${USBIP_RETRY_MAX:-300}
USBIP_HEALTH_INTERVAL=${USBIP_HEALTH_INTERVAL:-30}; USBIP_TTY_SETTLE_TIMEOUT=${USBIP_TTY_SETTLE_TIMEOUT:-30}
USBIP_RUN_DIR=${USBIP_RUN_DIR:-/run/usbip-client}; SYSFS_ROOT=${SYSFS_ROOT:-/sys}
STATUS_FILE="$USBIP_RUN_DIR/status"; PID_FILE="$USBIP_RUN_DIR/reconciler.pid"
RUNNING=1; OP_PID=""; OP_PGID=""
log() { printf '%s | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
write_status() {
  readiness=$1 message=$2 attached=${3:-0} tty_devices=${4:-0} retries=${5:-0}; mkdir -p "$USBIP_RUN_DIR"; tmp="$STATUS_FILE.$$"
  { printf 'liveness=healthy\nreadiness=%s\nstate=%s\n' "$readiness" "$readiness"; printf 'timestamp=%s\nserver=%s\nvendor=%s\n' "$(date +%s)" "$USB_IP" "$USBIP_VENDOR_ID"; printf 'attached=%s\ntty_devices=%s\nretries=%s\n' "$attached" "$tty_devices" "$retries"; printf 'message=%s\n' "$(printf '%s' "$message" | tr '\r\n=' '   ')"; } >"$tmp"; mv "$tmp" "$STATUS_FILE"
}
healthcheck() {
  [ -r "$STATUS_FILE" ] && [ -r "$PID_FILE" ] || return 1; pid=$(cat "$PID_FILE" 2>/dev/null) || return 1; kill -0 "$pid" 2>/dev/null || return 1
  timestamp=$(sed -n 's/^timestamp=//p' "$STATUS_FILE"); now=$(date +%s)
  [ -n "$timestamp" ] && [ $((now - timestamp)) -le $((USBIP_HEALTH_INTERVAL * 3 + USBIP_RETRY_MAX)) ]
}
if [ "${1:-}" = --health ]; then healthcheck; exit $?; fi
case "$USB_IP" in ''|*[!A-Za-z0-9.:_-]*) log "Invalid or empty USB_IP"; exit 2;; esac
case "$USBIP_VENDOR_ID" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) log "USBIP_VENDOR_ID must be four hexadecimal digits"; exit 2;; esac
command -v setsid >/dev/null 2>&1 || { log "setsid is required"; exit 2; }
run_usbip() { timeout -k 5 "$USBIP_COMMAND_TIMEOUT" usbip "$@"; }
remote_devices() { output=$(run_usbip list -r "$USB_IP" 2>&1); rc=$?; [ "$rc" -eq 0 ] || return "$rc"; printf '%s\n' "$output" | awk -v v="$USBIP_VENDOR_ID:" 'index(tolower($0),v){for(i=1;i<=NF;i++)if($i~/^[0-9]+-[0-9.]+:$/){gsub(/:$/,"",$i);print $i}}'; }
attached_devices() { output=$(run_usbip port 2>/dev/null); rc=$?; [ "$rc" -eq 0 ] || return "$rc"; printf '%s\n' "$output" | awk -v v="$USBIP_VENDOR_ID:" '/^Port [0-9][0-9]*:/{p=$2;gsub(/:/,"",p);match_vendor=0} index(tolower($0),v){match_vendor=1} match_vendor && /^[[:space:]]*[0-9]+-[0-9.]+ ->/{x=$0;sub(/^[[:space:]]*/,"",x);split(x,s," -> ");remote="unknown";if(index(s[2],"usbip://")){n=split(s[2],a,"/");remote=a[n]} print p "|" s[1] "|" remote;match_vendor=0}'; }
record_for_remote() { printf '%s\n' "$ATTACHED_RECORDS" | awk -F'|' -v r="$1" '$3==r{print;exit}'; }
tty_count_for_local() {
  b=$1; count=0
  for tty in "$SYSFS_ROOT"/class/tty/ttyUSB* "$SYSFS_ROOT"/class/tty/ttyACM*; do [ -e "$tty" ] || continue; target=$(readlink -f "$tty" 2>/dev/null || true); case "$target" in *"/$b/"*|*"/$b:"*) count=$((count+1));; esac; done
  if [ "$count" -eq 0 ]; then device=$(readlink -f "$SYSFS_ROOT/bus/usb/devices/$b" 2>/dev/null || true); if [ -n "$device" ] && [ -e "$device/idVendor" ] && [ "$(tr '[:upper:]' '[:lower:]' <"$device/idVendor" 2>/dev/null)" = "$USBIP_VENDOR_ID" ]; then count=$(find "$device" -type d \( -name 'ttyUSB*' -o -name 'ttyACM*' \) 2>/dev/null | wc -l | tr -d ' '); fi; fi
  printf '%s\n' "$count"
}
refresh_attached() { ATTACHED_RECORDS=$(attached_devices); }
count_healthy_attached() { ATTACHED_COUNT=0; TTY_TOTAL=0; for r in $ATTACHED_RECORDS; do b=$(printf '%s' "$r"|cut -d'|' -f2); c=$(tty_count_for_local "$b"); if [ "$c" -gt 0 ]; then ATTACHED_COUNT=$((ATTACHED_COUNT+1)); TTY_TOTAL=$((TTY_TOTAL+c)); fi; done; }
start_operation() { OP_LOG="$USBIP_RUN_DIR/operation.log"; : >"$OP_LOG"; setsid timeout -k 5 "$USBIP_COMMAND_TIMEOUT" usbip "$@" >"$OP_LOG" 2>&1 & OP_PID=$!; OP_PGID=$(ps -o pgid= -p "$OP_PID" 2>/dev/null | tr -d ' '); }
stop_operation() { [ -n "$OP_PID" ] || return 0; /bin/kill -TERM -- "-${OP_PGID:-$OP_PID}" 2>/dev/null || true; /bin/kill -KILL -- "-${OP_PGID:-$OP_PID}" 2>/dev/null || true; output=$(sed -n '1,20p' "$OP_LOG" 2>/dev/null||true); [ -n "$output" ]&&log "$output"; OP_PID=""; OP_PGID=""; }
wait_for_tty() { elapsed=0; while [ "$elapsed" -lt "$USBIP_TTY_SETTLE_TIMEOUT" ] && [ "$RUNNING" -eq 1 ]; do refresh_attached||true; count_healthy_attached; [ "$ATTACHED_COUNT" -ge "$USBIP_MIN_DEVICES" ]&&return 0; sleep 1;elapsed=$((elapsed+1));done;return 1; }
attach_remote() { remote=$1; log "Attaching Huawei device $remote from $USB_IP"; start_operation attach -r "$USB_IP" -b "$remote"; if wait_for_tty; then stop_operation; log "Huawei device $remote is imported and tty-ready"; return 0; fi; stop_operation; return 1; }
detach_remote() { port=$1; remote=$2; elapsed=0; log "Detaching unhealthy Huawei port $port"; start_operation detach -p "$port"; while [ "$elapsed" -lt "$USBIP_COMMAND_TIMEOUT" ]; do refresh_attached||true; [ -z "$(record_for_remote "$remote")" ]&&{ stop_operation;return 0;}; sleep 1;elapsed=$((elapsed+1));done;stop_operation;return 1; }
reconcile() {
  refresh_attached||{ LAST_ERROR="local USB/IP port listing failed or timed out";return 1;}; count_healthy_attached; [ "$ATTACHED_COUNT" -ge "$USBIP_MIN_DEVICES" ]&&return 0
  out=$(remote_devices); rc=$?; [ "$rc" -eq 0 ]||{ LAST_ERROR="remote device listing failed or timed out (rc=$rc)";return 1;}; REMOTE_DEVICES=$(printf '%s\n' "$out"|sed '/^$/d'|sort -u); n=$(printf '%s\n' "$REMOTE_DEVICES"|sed '/^$/d'|wc -l|tr -d ' '); [ "$n" -ge "$USBIP_MIN_DEVICES" ]||{ LAST_ERROR="found $n Huawei devices; expected at least $USBIP_MIN_DEVICES";return 1;}
  for remote in $REMOTE_DEVICES; do r=$(record_for_remote "$remote"); if [ -n "$r" ]; then port=$(printf '%s' "$r"|cut -d'|' -f1); detach_remote "$port" "$remote"||{ LAST_ERROR="targeted detach failed for $remote";return 1;}; sleep 2; fi; attach_remote "$remote"||{ LAST_ERROR="attach incomplete for $remote; server may require stale-session recovery";return 1;}; refresh_attached;count_healthy_attached; done
  [ "$ATTACHED_COUNT" -ge "$USBIP_MIN_DEVICES" ]||{ LAST_ERROR="Huawei import completed without usable tty";return 1;}
}
stop() { RUNNING=0;stop_operation;log "Stopping USB/IP reconciler"; }
trap stop INT TERM
mkdir -p "$USBIP_RUN_DIR"; printf '%s\n' "$$" >"$PID_FILE"; write_status starting "initializing" 0 0 0; log "USB/IP reconciler started for $USB_IP (vendor $USBIP_VENDOR_ID)"; modprobe vhci-hcd 2>/dev/null||true
retry_delay=$USBIP_RETRY_INITIAL;retry_count=0
while [ "$RUNNING" -eq 1 ]; do ATTACHED_COUNT=0;TTY_TOTAL=0;LAST_ERROR=""; if reconcile; then retry_count=0;retry_delay=$USBIP_RETRY_INITIAL;write_status ready "Huawei USB/IP devices are imported and tty-ready" "$ATTACHED_COUNT" "$TTY_TOTAL" 0;sleep "$USBIP_HEALTH_INTERVAL"&wait $!||true; else retry_count=$((retry_count+1));log "Recovery attempt $retry_count failed: $LAST_ERROR; retrying in ${retry_delay}s";write_status degraded "$LAST_ERROR" "$ATTACHED_COUNT" "$TTY_TOTAL" "$retry_count";sleep "$retry_delay"&wait $!||true;retry_delay=$((retry_delay*2));[ "$retry_delay" -le "$USBIP_RETRY_MAX" ]||retry_delay=$USBIP_RETRY_MAX;fi; [ "${USBIP_ONCE:-0}" = 1 ]&&exit 0;done
write_status stopped "reconciler stopped" "${ATTACHED_COUNT:-0}" "${TTY_TOTAL:-0}" "$retry_count";rm -f "$PID_FILE"
