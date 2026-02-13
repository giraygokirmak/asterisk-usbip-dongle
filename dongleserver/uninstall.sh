#!/bin/bash

# USB/IP Huawei Setup Uninstaller
# This script removes all components

set -e

echo "===== USB/IP Huawei Modem Setup Uninstaller ====="
echo

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then 
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Stop and disable services
echo "[1/4] Stopping and disabling services..."
systemctl stop usbip-huawei-monitor.service 2>/dev/null || true
systemctl stop usbip-huawei-bind.service 2>/dev/null || true
systemctl stop usbip-server.service 2>/dev/null || true

systemctl disable usbip-huawei-monitor.service 2>/dev/null || true
systemctl disable usbip-huawei-bind.service 2>/dev/null || true
systemctl disable usbip-server.service 2>/dev/null || true

# Remove systemd service files
echo "[2/4] Removing systemd service files..."
rm -f /etc/systemd/system/usbip-server.service
rm -f /etc/systemd/system/usbip-huawei-bind.service
rm -f /etc/systemd/system/usbip-huawei-monitor.service

# Remove udev rule
echo "[3/4] Removing udev rule..."
rm -f /etc/udev/rules.d/99-usbip-huawei.rules

# Remove script
echo "[4/4] Removing binding script..."
rm -f /usr/local/bin/usbip-huawei-bind.sh

# Reload systemd and udev
systemctl daemon-reload
udevadm control --reload-rules

echo
echo "===== Uninstallation Complete! ====="
echo
echo "Note: Log file /var/log/usbip-huawei.log was kept for reference"
echo "You can remove it manually with: sudo rm /var/log/usbip-huawei.log"
echo
