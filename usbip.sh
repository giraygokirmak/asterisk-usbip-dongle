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
        | awk '{print $1}' \
        | tr -d ':'
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

# Check if device is truly working: attached via usbip AND tty ports visible
device_present() {
    usbip port 2>/dev/null | grep -q "12d1:" && [ -n "$(get_tty_ports)" ]
}

# Detach ALL currently attached usbip ports to ensure a clean slate
cleanup_ghost_ports() {
    PORTS=$(usbip port 2>/dev/null | grep "^usbip port\|^Port " | sed -n 's/.*Port \([0-9][0-9]*\).*/\1/p')
    if [ -z "$PORTS" ]; then
        # Alternative format used by some versions
        PORTS=$(usbip port 2>/dev/null | awk '/^Port/{print $2}' | tr -d ':')
    fi
    for PORT in $PORTS; do
        log "Detaching stale port: $PORT"
        usbip detach -p "$PORT" 2>/dev/null
        sleep 1
    done
}

attach_devices() {
    DEVICES=$(find_remote_devices)
    if [ -z "$DEVICES" ]; then
        log "No remote Huawei devices found on $CLEAN_IP"
        return 1
    fi
    for BUSID in $DEVICES; do
        log "Attaching device $BUSID from $CLEAN_IP"
        usbip attach -r "$CLEAN_IP" -b "$BUSID" >>"$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            log "Attach failed for $BUSID"
            return 1
        fi
        sleep 2
    done

    sleep 3
    if wait_for_tty; then
        PORTS=$(get_tty_ports)
        chmod 777 $PORTS 2>/dev/null
        log "Devices ready: $PORTS"
        asterisk -rx "dongle reload gracefully" >/dev/null 2>&1
        return 0
    else
        log "TTY ports not detected after attach — will retry"
        return 1
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

    log "Huawei device missing or tty gone, cleaning up and reconnecting..."
    cleanup_ghost_ports
    sleep 2

    attach_devices || {
        log "Attach cycle failed, retrying in 10s..."
        sleep 10
    }

    sleep 10
done
