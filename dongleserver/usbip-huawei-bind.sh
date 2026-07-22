#!/bin/bash
set -uo pipefail

VENDOR_ID="${USBIP_VENDOR_ID:-12d1}"
COMMAND_TIMEOUT="${USBIP_COMMAND_TIMEOUT:-10}"

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }
run_usbip() { timeout -k 5 "$COMMAND_TIMEOUT" usbip "$@"; }

is_bound() {
    [[ -e "/sys/bus/usb/drivers/usbip-host/$1" ]]
}

find_huawei_busids() {
    run_usbip list -l 2>/dev/null |
        awk -v vendor="$VENDOR_ID:" '
            /busid/ { candidate=$3; gsub(/[(),]/, "", candidate) }
            index(tolower($0), vendor) && candidate != "" { print candidate; candidate="" }
        ' | sort -u
}

bind_device() {
    local busid=$1 output rc
    if is_bound "$busid"; then
        log "$busid is already owned by usbip-host; leaving it untouched"
        return 0
    fi

    log "Binding Huawei device $busid"
    output=$(run_usbip bind -b "$busid" 2>&1)
    rc=$?
    [[ -n "$output" ]] && log "$output"
    if [[ $rc -eq 0 ]] || grep -qi "already bound" <<<"$output"; then
        return 0
    fi
    log "ERROR: bind failed or timed out for $busid (rc=$rc)"
    return 1
}

main() {
    local busids busid failures=0
    pgrep -x usbipd >/dev/null || { log "ERROR: usbipd is not running"; return 1; }
    busids=$(find_huawei_busids)
    if [[ -z "$busids" ]]; then
        log "No Huawei devices detected"
        return 0
    fi

    while read -r busid; do
        [[ -z "$busid" ]] && continue
        bind_device "$busid" || failures=$((failures + 1))
    done <<<"$busids"
    [[ $failures -eq 0 ]]
}

main "$@"
