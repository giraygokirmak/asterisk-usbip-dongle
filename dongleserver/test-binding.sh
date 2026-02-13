#!/bin/bash

# Test script to verify the fix is working correctly
# This simulates what the monitor does and shows you what it will do

echo "===== USB/IP Binding Test ====="
echo "This script shows you what the monitor will do WITHOUT actually doing it"
echo

# Get all Huawei device bus IDs (same command as the real script)
echo "[1] Scanning for Huawei modems..."
HUAWEI_BUSBIDS=$(usbip list -l 2>/dev/null | awk '/busid/ {id=$3} /Huawei/ {print id}' | paste -sd "," -)

if [ -z "$HUAWEI_BUSBIDS" ]; then
    echo "    ✗ No Huawei modems detected"
    exit 0
fi

echo "    ✓ Found Huawei modems: $HUAWEI_BUSBIDS"
echo

# Get currently bound devices (using the FIXED method)
echo "[2] Checking which devices are already bound..."
BOUND_DEVICES=$(usbip list -l 2>/dev/null | grep -B1 "usbip-host" | awk '/busid/ {print $1}' | tr -d ',' || echo "")

if [ -z "$BOUND_DEVICES" ]; then
    echo "    ℹ No devices currently bound to usbip-host"
else
    echo "    ✓ Currently bound devices: $BOUND_DEVICES"
fi
echo

# Show detailed status for each Huawei device
echo "[3] Detailed status of each Huawei device:"
IFS=',' read -ra BUSID_ARRAY <<< "$HUAWEI_BUSBIDS"

for busid in "${BUSID_ARRAY[@]}"; do
    busid=$(echo "$busid" | xargs)
    
    if [ -z "$busid" ]; then
        continue
    fi
    
    echo
    echo "  Device: $busid"
    
    # Check if it exists
    if ! usbip list -l 2>/dev/null | grep -q "$busid"; then
        echo "    ✗ Device not found in local USB devices!"
        continue
    fi
    
    # Check if bound
    if usbip list -l 2>/dev/null | grep -A1 "$busid" | grep -q "usbip-host"; then
        echo "    ✓ Status: ALREADY BOUND to usbip-host"
        echo "    → Action: SKIP (will not disturb - clients stay connected)"
        
        # Check if clients are connected
        CLIENTS=$(usbip list -r localhost 2>/dev/null | grep -A5 "$busid" | grep -c "port" || echo "0")
        if [ "$CLIENTS" -gt 0 ]; then
            echo "    ℹ Active client connections detected!"
        fi
    else
        echo "    ℹ Status: NOT BOUND"
        echo "    → Action: WILL BIND this device"
        
        # Show what driver it currently has
        CURRENT_DRIVER=$(usbip list -l 2>/dev/null | grep -A1 "$busid" | grep -oP '\([^)]+\)' | head -1 | tr -d '()')
        if [ -n "$CURRENT_DRIVER" ]; then
            echo "    ℹ Current driver: $CURRENT_DRIVER"
        fi
    fi
done

echo
echo "===== Summary ====="
echo

# Count what will happen
TOTAL=$(echo "$HUAWEI_BUSBIDS" | tr ',' '\n' | wc -l)
ALREADY_BOUND=0
TO_BIND=0

for busid in "${BUSID_ARRAY[@]}"; do
    busid=$(echo "$busid" | xargs)
    if [ -z "$busid" ]; then
        continue
    fi
    
    if usbip list -l 2>/dev/null | grep -A1 "$busid" | grep -q "usbip-host"; then
        ((ALREADY_BOUND++))
    else
        ((TO_BIND++))
    fi
done

echo "Total Huawei devices found: $TOTAL"
echo "Already bound (will be left alone): $ALREADY_BOUND"
echo "Will be bound: $TO_BIND"
echo

if [ $ALREADY_BOUND -gt 0 ]; then
    echo "✓ GOOD: Already-bound devices will NOT be touched (no disconnections!)"
fi

if [ $TO_BIND -gt 0 ]; then
    echo "ℹ New devices will be bound and made available for clients"
fi

echo
echo "===== How to Monitor in Real-Time ====="
echo "Run this command to watch what the monitor service is doing:"
echo "  sudo tail -f /var/log/usbip-huawei.log"
echo
echo "You should see messages like:"
echo "  'Device X-X is already bound to usbip-host - skipping'"
echo
