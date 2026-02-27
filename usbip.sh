#!/bin/sh
LOGFILE="/var/log/usbip-watchdog.log"
log() {
    echo "$(date '+%F %T') | $1" | tee -a "$LOGFILE"
}
CLEAN_IP=$(echo "$USB_IP" | tr -d '\r\n ')
log "USBIP watchdog started (target: $CLEAN_IP)"
modprobe vhci-hcd 2>/dev/null
modprobe usbip-core 2>/dev/null

wait_for_network() {
    until ping -c1 -W1 "$CLEAN_IP" >/dev/null 2>&1; do
        log "Network not ready, waiting..."
        sleep 2
    done
}

find_remote_devices() {
    usbip list -r "$CLEAN_IP" 2>/dev/null \
        | grep "12d1:" \
        | awk '{print $1}'
}

device_present() {
    lsusb | grep -q "12d1:"
}

get_tty_ports() {
    ls /dev/ttyUSB* 2>/dev/null
}

wait_for_tty() {
    log "Waiting for tty ports..."
    for i in $(seq 1 30); do
        PORTS=$(get_tty_ports)
        [ -n "$PORTS" ] && return 0
        sleep 1
    done
    return 1
}

already_attached_busid() {
    BUSID=$1
    usbip port 2>/dev/null | grep -q "$BUSID"
}

cleanup_ghost_ports() {
    for PORT in $(usbip port 2>/dev/null | grep "$CLEAN_IP" | sed -n 's/.*Port \([0-9]*\).*/\1/p'); do
        log "Cleaning stale port: $PORT"
        usbip detach -p "$PORT" 2>/dev/null
        sleep 1
    done
}

attach_devices() {
    DEVICES=$(find_remote_devices)
    if [ -z "$DEVICES" ]; then
        log "No remote Huawei devices found"
        return
    fi
    for BUSID in $DEVICES; do
        if already_attached_busid "$BUSID"; then
            log "Already attached: $BUSID"
            continue
        fi
        log "Attaching device $BUSID"
        usbip attach -r "$CLEAN_IP" -b "$BUSID" >>"$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            log "Attach failed for $BUSID"
            continue
        fi
        sleep 2
    done
    sleep 3
    if wait_for_tty; then
        PORTS=$(get_tty_ports)
        chmod 777 $PORTS 2>/dev/null
        log "Devices ready: $PORTS"
        asterisk -rx "dongle reload gracefully" >/dev/null 2>&1
    else
        log "TTY ports not detected"
    fi
}

while true; do
    wait_for_network
    if device_present; then
        PORTS=$(get_tty_ports)
        chmod 777 $PORTS 2>/dev/null
        sleep 30
        continue
    fi
    cleanup_ghost_ports
    log "Huawei device missing, attempting reconnect..."
    attach_devices
    sleep 10
done
