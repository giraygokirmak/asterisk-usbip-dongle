#!/bin/bash

# USB/IP Huawei Modem Binding Script
# This script automatically detects and binds Huawei modems for USB/IP sharing

set -euo pipefail

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

# Function to get currently bound devices (bound to usbip-host driver)
get_bound_devices() {
    # A device is "bound" if it's using the usbip-host driver
    # Format from 'usbip list -l' shows driver in parentheses like (usbip-host)
    usbip list -l 2>/dev/null | grep -B1 "usbip-host" | awk '/busid/ {print $1}' | tr -d ',' || echo ""
}

# Function to unbind a device
unbind_device() {
    local busid=$1
    log "Unbinding device: $busid"
    if sudo usbip unbind -b "$busid" 2>/dev/null; then
        log "Successfully unbound $busid"
        return 0
    else
        log "Warning: Failed to unbind $busid (may not have been bound)"
        return 1
    fi
}

# Function to bind a device
bind_device() {
    local busid=$1
    log "Checking device: $busid"
    
    # Check if device exists
    if ! usbip list -l 2>/dev/null | grep -q "$busid"; then
        log "ERROR: Device $busid not found in local USB devices"
        return 1
    fi
    
    # Check if already bound to usbip-host driver
    if usbip list -l 2>/dev/null | grep -A1 "$busid" | grep -q "usbip-host"; then
        log "Device $busid is already bound to usbip-host - skipping (DO NOT DISTURB ACTIVE CONNECTIONS)"
        return 0
    fi
    
    # Device exists but is not bound - safe to bind now
    log "Binding device: $busid"
    if sudo usbip bind -b "$busid" 2>&1 | tee -a "$LOGFILE"; then
        log "Successfully bound $busid"
        return 0
    else
        log "ERROR: Failed to bind $busid"
        return 1
    fi
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
    
    # Get currently bound devices
    BOUND_DEVICES=$(get_bound_devices)
    
    # Convert comma-separated list to array
    IFS=',' read -ra BUSID_ARRAY <<< "$HUAWEI_BUSBIDS"
    
    # Bind each device
    for busid in "${BUSID_ARRAY[@]}"; do
        # Trim whitespace
        busid=$(echo "$busid" | xargs)
        
        if [ -z "$busid" ]; then
            continue
        fi
        
        # Check if already bound
        if echo "$BOUND_DEVICES" | grep -q "$busid"; then
            log "Device $busid is already bound, skipping"
        else
            bind_device "$busid"
        fi
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
    
    # Monitor mode - continuously check for devices
    while true; do
        sleep 30  # Check every 30 seconds (reduced from 10 to minimize overhead)
        
        # Check if usbipd is still running
        if ! check_usbipd; then
            log "WARNING: usbipd stopped running!"
            sleep 5
            continue
        fi
        
        # Re-scan and bind if needed (only binds unbound devices)
        bind_huawei_modems
    done
else
    log "Single run completed. Exiting."
fi

log "===== USB/IP Huawei Binding Script Finished ====="
