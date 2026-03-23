#!/bin/bash

# USB/IP Huawei Modem Binding Script
# This script automatically detects and binds Huawei modems for USB/IP sharing

# REMOVED: set -euo pipefail — caused crash-loop when bind returned non-zero
# (e.g. "already bound"), killing the monitor loop and disrupting active connections.
set -uo pipefail

LOGFILE="/var/log/usbip-huawei.log"
LOCKFILE="/var/run/usbip-huawei.lock"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Cleanup function
cleanup() {
    rm -f "$LOCKFILE"
}

trap cleanup EXIT

# Check if script is already running
if [ -f "$LOCKFILE" ]; then
    LOCK_PID=$(cat "$LOCKFILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        log "Script already running with PID $LOCK_PID. Exiting."
        exit 0
    else
        log "Removing stale lock file"
        rm -f "$LOCKFILE"
    fi
fi

echo $$ > "$LOCKFILE"

# Function to check if usbipd is running
check_usbipd() {
    if ! pgrep -x usbipd > /dev/null; then
        log "ERROR: usbipd daemon is not running!"
        return 1
    fi
    return 0
}

# Function to check if a device is currently bound to usbip-host
# Uses sysfs — reliable, no text parsing required.
is_bound() {
    local busid=$1
    [ -e "/sys/bus/usb/drivers/usbip-host/$busid" ]
}

# Function to check if a device is currently attached by a remote client
# When attached, the device symlink moves from usbip-host to usbip-vudc or similar.
# The reliable signal: device is NOT listed as exportable by usbipd.
# We detect this by checking if the usbip-host entry exists but device is in use:
is_attached_by_client() {
    local busid=$1
    # If bound to usbip-host AND in usbipd's "in use" state,
    # sysfs shows the device but status file reads "used"
    local status_file="/sys/bus/usb/drivers/usbip-host/$busid/usbip_status"
    if [ -f "$status_file" ]; then
        local status
        status=$(cat "$status_file" 2>/dev/null || echo "0")
        # status 1 = available, status 2 = used by client, status 3 = error
        [ "$status" = "2" ] && return 0
    fi
    return 1
}

# Function to bind a device
bind_device() {
    local busid=$1
    log "Checking device: $busid"

    # Check if device exists in local USB tree
    if ! usbip list -l 2>/dev/null | grep -q "$busid"; then
        log "ERROR: Device $busid not found in local USB devices"
        return 1
    fi

    # FIX: Use sysfs instead of 'usbip list -l | grep -A1' (which only checks
    # one line after busid and misses the driver field).
    if is_bound "$busid"; then
        if is_attached_by_client "$busid"; then
            log "Device $busid is bound and actively used by a client — not touching it"
        else
            log "Device $busid is already bound to usbip-host — skipping"
        fi
        return 0
    fi

    # Device exists but is not bound — safe to bind
    log "Binding device: $busid"
    local bind_output
    bind_output=$(sudo usbip bind -b "$busid" 2>&1)
    local bind_rc=$?
    echo "$bind_output" | tee -a "$LOGFILE"

    if [ $bind_rc -eq 0 ]; then
        log "Successfully bound $busid"
        return 0
    fi

    # usbip bind exits non-zero even for "already bound" — treat that as success
    if echo "$bind_output" | grep -q "already bound"; then
        log "Device $busid was already bound (race condition) — OK"
        return 0
    fi

    log "ERROR: Failed to bind $busid (rc=$bind_rc)"
    return 1
}

# Main function to detect and bind Huawei modems
bind_huawei_modems() {
    log "Scanning for Huawei modems..."

    # Get all Huawei device bus IDs
    HUAWEI_BUSBIDS=$(usbip list -l 2>/dev/null | awk '/busid/ {id=$3} /Huawei/ {print id}' | paste -sd "," -)

    if [ -z "$HUAWEI_BUSBIDS" ]; then
        log "No Huawei modems detected"
        return 0
    fi

    log "Found Huawei modems: $HUAWEI_BUSBIDS"

    # Convert comma-separated list to array
    IFS=',' read -ra BUSID_ARRAY <<< "$HUAWEI_BUSBIDS"

    # Bind each device (bind_device handles already-bound gracefully)
    for busid in "${BUSID_ARRAY[@]}"; do
        busid=$(echo "$busid" | xargs)
        [ -z "$busid" ] && continue
        bind_device "$busid" || true   # never let a single device failure abort the loop
    done

    log "Binding process completed"
}

# Main execution
log "===== USB/IP Huawei Binding Script Started ====="

# Check if usbipd is running
if ! check_usbipd; then
    log "Waiting for usbipd to start..."
    sleep 2
    if ! check_usbipd; then
        log "FATAL: usbipd is not running. Exiting."
        exit 1
    fi
fi

# Perform initial binding
bind_huawei_modems

# If running in continuous mode (with argument)
if [ "${1:-}" = "--monitor" ]; then
    log "Entering monitor mode..."

    while true; do
        sleep 30

        if ! check_usbipd; then
            log "WARNING: usbipd stopped running!"
            sleep 5
            continue
        fi

        bind_huawei_modems
    done
else
    log "Single run completed. Exiting."
fi

log "===== USB/IP Huawei Binding Script Finished ====="
