#!/bin/sh
set -u

USB_IP=$(printf '%s' "${USB_IP:-}" | tr -d '\r\n ')
USBIP_VENDOR_ID=$(printf '%s' "${USBIP_VENDOR_ID:-12d1}" | tr '[:upper:]' '[:lower:]')
USBIP_MIN_DEVICES=${USBIP_MIN_DEVICES:-1}
USBIP_COMMAND_TIMEOUT=${USBIP_COMMAND_TIMEOUT:-10}
USBIP_RETRY_INITIAL=${USBIP_RETRY_INITIAL:-10}
USBIP_RETRY_MAX=${USBIP_RETRY_MAX:-300}
USBIP_HEALTH_INTERVAL=${USBIP_HEALTH_INTERVAL:-30}
USBIP_TTY_SETTLE_TIMEOUT=${USBIP_TTY_SETTLE_TIMEOUT:-30}
USBIP_RUN_DIR=${USBIP_RUN_DIR:-/run/usbip-client}
SYSFS_ROOT=${SYSFS_ROOT:-/sys}
STATUS_FILE="$USBIP_RUN_DIR/status"
RUNNING=1

log() { printf '%s | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }

write_status() {
    state=$1 message=$2 attached=${3:-0} tty_devices=${4:-0} retries=${5:-0}
    mkdir -p "$USBIP_RUN_DIR"
    tmp="$STATUS_FILE.$$"
    {
        printf 'state=%s\ntimestamp=%s\nserver=%s\nvendor=%s\n' "$state" "$(date +%s)" "$USB_IP" "$USBIP_VENDOR_ID"
        printf 'attached=%s\ntty_devices=%s\nretries=%s\n' "$attached" "$tty_devices" "$retries"
        printf 'message=%s\n' "$(printf '%s' "$message" | tr '\r\n=' '   ')"
    } >"$tmp"
    mv "$tmp" "$STATUS_FILE"
}

healthcheck() {
    [ -r "$STATUS_FILE" ] || return 1
    state=$(sed -n 's/^state=//p' "$STATUS_FILE")
    timestamp=$(sed -n 's/^timestamp=//p' "$STATUS_FILE")
    now=$(date +%s)
    [ "$state" = healthy ] && [ -n "$timestamp" ] &&
        [ $((now - timestamp)) -le $((USBIP_HEALTH_INTERVAL * 3 + USBIP_RETRY_MAX)) ]
}

if [ "${1:-}" = --health ]; then healthcheck; exit $?; fi
case "$USB_IP" in ''|*[!A-Za-z0-9.:_-]*) log "Invalid or empty USB_IP"; exit 2;; esac
case "$USBIP_VENDOR_ID" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) log "USBIP_VENDOR_ID must be four hexadecimal digits"; exit 2;; esac

run_usbip() { timeout -k 5 "$USBIP_COMMAND_TIMEOUT" usbip "$@"; }

remote_devices() {
    output=$(run_usbip list -r "$USB_IP" 2>&1); rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
    printf "%s\n" "$output" | awk -v vendor="$USBIP_VENDOR_ID:" '
        index(tolower($0), vendor) { for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+-[0-9.]+:$/) { busid=$i; gsub(/:$/, "", busid); print busid } }
    '
}

# Output: vhci-port|local-usb-busid|remote-usb-busid
attached_devices() {
    output=$(run_usbip port 2>/dev/null); rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
    printf "%s\n" "$output" | awk '
        /^Port [0-9][0-9]*:/ { port=$2; gsub(/:/, "", port) }
        / -> usbip:\/\// { line=$0; sub(/^[[:space:]]*/, "", line); split(line, sides, " -> "); count=split(sides[2], path, "/"); print port "|" sides[1] "|" path[count] }
    '
}

record_for_remote() { printf '%s\n' "$ATTACHED_RECORDS" | awk -F'|' -v remote="$1" '$3 == remote { print; exit }'; }

tty_count_for_local() {
    device="$SYSFS_ROOT/bus/usb/devices/$1"
    [ -e "$device/idVendor" ] || { printf '0\n'; return; }
    vendor=$(tr '[:upper:]' '[:lower:]' <"$device/idVendor" 2>/dev/null || true)
    [ "$vendor" = "$USBIP_VENDOR_ID" ] || { printf '0\n'; return; }
    find -L "$device" -type d -name 'ttyUSB*' 2>/dev/null | wc -l | tr -d ' '
}

refresh_attached() { ATTACHED_RECORDS=$(attached_devices); }
attach_remote() {
    log "Attaching Huawei device $1 from $USB_IP"
    output=$(run_usbip attach -r "$USB_IP" -b "$1" 2>&1); rc=$?
    [ -n "$output" ] && log "$output"
    return "$rc"
}
detach_port() {
    log "Detaching only unhealthy Huawei port $1 (remote busid $2)"
    output=$(run_usbip detach -p "$1" 2>&1); rc=$?
    [ -n "$output" ] && log "$output"
    return "$rc"
}

wait_for_device_tty() {
    remote=$1 elapsed=0
    while [ "$elapsed" -lt "$USBIP_TTY_SETTLE_TIMEOUT" ] && [ "$RUNNING" -eq 1 ]; do
        refresh_attached; record=$(record_for_remote "$remote")
        if [ -n "$record" ]; then
            local_busid=$(printf '%s' "$record" | cut -d'|' -f2); count=$(tty_count_for_local "$local_busid")
            [ "$count" -gt 0 ] && return 0
        fi
        sleep 1; elapsed=$((elapsed + 1))
    done
    return 1
}

reconcile() {
    remote_output=$(remote_devices); remote_rc=$?
    if [ "$remote_rc" -ne 0 ]; then LAST_ERROR="remote device listing failed or timed out (rc=$remote_rc)"; return 1; fi
    REMOTE_DEVICES=$(printf '%s\n' "$remote_output" | sed '/^$/d' | sort -u)
    remote_count=$(printf '%s\n' "$REMOTE_DEVICES" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$remote_count" -lt "$USBIP_MIN_DEVICES" ]; then LAST_ERROR="found $remote_count Huawei devices; expected at least $USBIP_MIN_DEVICES"; return 1; fi

    refresh_attached || { LAST_ERROR="local USB/IP port listing failed or timed out"; return 1; }; healthy=0; tty_total=0
    for remote in $REMOTE_DEVICES; do
        record=$(record_for_remote "$remote")
        if [ -n "$record" ]; then
            port=$(printf '%s' "$record" | cut -d'|' -f1); local_busid=$(printf '%s' "$record" | cut -d'|' -f2)
            tty_count=$(tty_count_for_local "$local_busid")
            if [ "$tty_count" -gt 0 ]; then healthy=$((healthy + 1)); tty_total=$((tty_total + tty_count)); continue; fi
            detach_port "$port" "$remote" || { LAST_ERROR="targeted detach failed or timed out for $remote on port $port"; return 1; }
            sleep 2
        fi
        attach_remote "$remote" || { LAST_ERROR="attach failed or timed out for $remote"; return 1; }
        wait_for_device_tty "$remote" || { LAST_ERROR="no Huawei tty devices appeared for $remote"; return 1; }
        refresh_attached; record=$(record_for_remote "$remote"); local_busid=$(printf '%s' "$record" | cut -d'|' -f2)
        tty_count=$(tty_count_for_local "$local_busid"); healthy=$((healthy + 1)); tty_total=$((tty_total + tty_count))
    done
    ATTACHED_COUNT=$healthy; TTY_TOTAL=$tty_total
    [ "$healthy" -ge "$USBIP_MIN_DEVICES" ]
}

stop() { RUNNING=0; log "Stopping USB/IP reconciler without detaching devices"; }
trap stop INT TERM
mkdir -p "$USBIP_RUN_DIR"
write_status starting "initializing" 0 0 0
log "USB/IP reconciler started for $USB_IP (vendor $USBIP_VENDOR_ID)"
modprobe vhci-hcd 2>/dev/null || true

retry_delay=$USBIP_RETRY_INITIAL; retry_count=0
while [ "$RUNNING" -eq 1 ]; do
    ATTACHED_COUNT=0; TTY_TOTAL=0; LAST_ERROR=""
    if reconcile; then
        retry_count=0; retry_delay=$USBIP_RETRY_INITIAL
        write_status healthy "all discovered Huawei devices have tty ports" "$ATTACHED_COUNT" "$TTY_TOTAL" 0
        sleep "$USBIP_HEALTH_INTERVAL" & wait $! || true
    else
        retry_count=$((retry_count + 1)); log "Recovery attempt $retry_count failed: $LAST_ERROR; retrying in ${retry_delay}s"
        write_status degraded "$LAST_ERROR" "$ATTACHED_COUNT" "$TTY_TOTAL" "$retry_count"
        sleep "$retry_delay" & wait $! || true
        retry_delay=$((retry_delay * 2)); [ "$retry_delay" -le "$USBIP_RETRY_MAX" ] || retry_delay=$USBIP_RETRY_MAX
    fi
    [ "${USBIP_ONCE:-0}" = 1 ] && exit 0
done
write_status stopped "reconciler stopped without detaching devices" "${ATTACHED_COUNT:-0}" "${TTY_TOTAL:-0}" "$retry_count"
