#!/bin/bash

# USB/IP Huawei Setup Validation Script
# This script checks if everything is properly configured

echo "===== USB/IP Huawei Setup Validator ====="
echo

PASSED=0
FAILED=0

check_pass() {
    echo "✓ $1"
    ((PASSED++))
}

check_fail() {
    echo "✗ $1"
    ((FAILED++))
}

check_warn() {
    echo "⚠ $1"
}

# Check if running as root
CURRENT_UID=$(id -u)
if [ "$CURRENT_UID" -eq 0 ]; then
    check_warn "Running as root (recommended for full diagnostics)"
else
    check_warn "Not running as root (some checks may be limited)"
    echo "  Run with: sudo ./validate.sh"
fi

echo
echo "=== Checking Dependencies ==="

# Check for usbip command
if command -v usbip &> /dev/null; then
    check_pass "usbip command found"
    usbip version 2>&1 | head -1
else
    check_fail "usbip command NOT found"
    echo "  Install: sudo apt install linux-tools-generic usbip"
fi

# Check for usbipd
if command -v usbipd &> /dev/null; then
    check_pass "usbipd command found"
else
    check_fail "usbipd command NOT found"
fi

# Check for systemctl
if command -v systemctl &> /dev/null; then
    check_pass "systemctl found (systemd available)"
else
    check_fail "systemctl NOT found (systemd required)"
fi

echo
echo "=== Checking Kernel Modules ==="

# Check usbip-host module
if lsmod | grep -q usbip_host; then
    check_pass "usbip_host module loaded"
else
    check_warn "usbip_host module not loaded"
    echo "  Load with: sudo modprobe usbip-host"
fi

# Check if module is available
if modinfo usbip-host &> /dev/null 2>&1 || modinfo usbip_host &> /dev/null 2>&1; then
    check_pass "usbip_host module available"
else
    check_fail "usbip_host module NOT available"
    echo "  Install linux-tools or kernel modules"
fi

echo
echo "=== Checking Installed Files ==="

# Check script
if [ -f /usr/local/bin/usbip-huawei-bind.sh ]; then
    check_pass "Binding script installed"
    if [ -x /usr/local/bin/usbip-huawei-bind.sh ]; then
        check_pass "Binding script is executable"
    else
        check_fail "Binding script is NOT executable"
    fi
else
    check_fail "Binding script NOT installed"
    echo "  Expected at: /usr/local/bin/usbip-huawei-bind.sh"
fi

# Check systemd services
for service in usbip-server usbip-huawei-bind usbip-huawei-monitor; do
    if [ -f "/etc/systemd/system/${service}.service" ]; then
        check_pass "${service}.service installed"
    else
        check_fail "${service}.service NOT installed"
    fi
done

# Check udev rule
if [ -f /etc/udev/rules.d/99-usbip-huawei.rules ]; then
    check_pass "Udev rule installed"
else
    check_fail "Udev rule NOT installed"
fi

# Check log file
if [ -f /var/log/usbip-huawei.log ]; then
    check_pass "Log file exists"
    if [ "$CURRENT_UID" -eq 0 ]; then
        LOG_SIZE=$(stat -f "%z" /var/log/usbip-huawei.log 2>/dev/null || stat -c "%s" /var/log/usbip-huawei.log 2>/dev/null || echo "0")
        echo "  Log size: $LOG_SIZE bytes"
    fi
else
    check_warn "Log file does not exist yet"
fi

if [ "$CURRENT_UID" -eq 0 ]; then
    echo
    echo "=== Checking Service Status ==="
    
    # Check services
    for service in usbip-server usbip-huawei-bind usbip-huawei-monitor; do
        if systemctl is-enabled ${service}.service &> /dev/null; then
            check_pass "${service}.service is enabled"
        else
            check_warn "${service}.service is NOT enabled"
        fi
        
        if systemctl is-active ${service}.service &> /dev/null; then
            check_pass "${service}.service is running"
        else
            check_warn "${service}.service is NOT running"
        fi
    done
    
    # Check if usbipd process is running
    if pgrep -x usbipd > /dev/null; then
        check_pass "usbipd process is running"
        echo "  PID: $(pgrep -x usbipd)"
    else
        check_warn "usbipd process is NOT running"
    fi
    
    echo
    echo "=== Checking USB Devices ==="
    
    # List USB devices
    if command -v usbip &> /dev/null; then
        echo "Local USB devices:"
        usbip list -l 2>/dev/null | grep -E "(busid|Huawei)" | head -20 || echo "  No devices or command failed"
        
        echo
        echo "Bound/shared devices:"
        usbip list -r localhost 2>/dev/null | head -20 || echo "  No devices or service not running"
    fi
    
    echo
    echo "=== Recent Log Entries ==="
    if [ -f /var/log/usbip-huawei.log ]; then
        echo "Last 10 lines from /var/log/usbip-huawei.log:"
        tail -10 /var/log/usbip-huawei.log
    fi
    
    echo
    echo "=== Recent Journal Entries ==="
    echo "Last 5 entries from usbip-huawei-bind service:"
    journalctl -u usbip-huawei-bind.service -n 5 --no-pager 2>/dev/null || echo "  No journal entries"
fi

echo
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo

if [ $FAILED -eq 0 ]; then
    echo "✓ All critical checks passed!"
    if [ "$CURRENT_UID" -ne 0 ]; then
        echo "  Run with sudo for complete diagnostics"
    fi
else
    echo "✗ Some checks failed. Please review the output above."
    echo "  Run ./install.sh to install or fix the setup"
fi

echo
echo "For more information, see README.md"
