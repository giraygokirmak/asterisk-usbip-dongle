#!/bin/bash

# USB/IP Huawei Setup Installation Script
# This script installs all necessary components for automatic USB/IP sharing

set -e

echo "===== USB/IP Huawei Modem Setup Installer ====="
echo

# Check if running as root (compatible with both bash and sh)
if [ "$(id -u)" -ne 0 ]; then 
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Check if usbip is installed (check for actual binary)
if ! which usbip >/dev/null 2>&1; then
    echo "ERROR: usbip is not installed!"
    echo "Please install it first:"
    echo "  Ubuntu/Debian: sudo apt install linux-tools-generic usbip"
    echo "  Fedora/RHEL:   sudo dnf install usbip-utils"
    echo "  Arch:          sudo pacman -S usbip"
    exit 1
fi

# Verify usbip actually works
if ! usbip version >/dev/null 2>&1; then
    echo "ERROR: usbip is installed but not working properly"
    echo "You may need to install the correct linux-tools package for your kernel:"
    echo "  Current kernel: $(uname -r)"
    echo "  Try: sudo apt install linux-tools-$(uname -r) linux-tools-generic"
    exit 1
fi

echo "Found usbip: $(which usbip)"
usbip version 2>&1 | head -1 || true

# Create log directory
echo "[1/6] Creating log directory..."
mkdir -p /var/log
touch /var/log/usbip-huawei.log
chmod 644 /var/log/usbip-huawei.log

# Install the binding script
echo "[2/6] Installing binding script..."
cp usbip-huawei-bind.sh /usr/local/bin/
chmod +x /usr/local/bin/usbip-huawei-bind.sh

# Install systemd service files
echo "[3/6] Installing systemd service files..."
cp usbip-server.service /etc/systemd/system/
cp usbip-huawei-bind.service /etc/systemd/system/
cp usbip-huawei-monitor.service /etc/systemd/system/

# Install udev rule
echo "[4/6] Installing udev rule..."
cp 99-usbip-huawei.rules /etc/udev/rules.d/

# Reload systemd and udev
echo "[5/6] Reloading systemd and udev..."
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

# Enable and start services
echo "[6/6] Enabling and starting services..."
systemctl enable usbip-server.service
systemctl enable usbip-huawei-bind.service
systemctl enable usbip-huawei-monitor.service

systemctl start usbip-server.service
sleep 2
systemctl start usbip-huawei-bind.service
systemctl start usbip-huawei-monitor.service

echo
echo "===== Installation Complete! ====="
echo
echo "Service Status:"
systemctl status usbip-server.service --no-pager -l || true
echo
systemctl status usbip-huawei-bind.service --no-pager -l || true
echo
systemctl status usbip-huawei-monitor.service --no-pager -l || true
echo
echo "Useful Commands:"
echo "  Check status:       systemctl status usbip-server.service"
echo "  View logs:          journalctl -u usbip-server.service -f"
echo "  View bind logs:     journalctl -u usbip-huawei-bind.service -f"
echo "  View monitor logs:  journalctl -u usbip-huawei-monitor.service -f"
echo "  View script logs:   tail -f /var/log/usbip-huawei.log"
echo "  List bound devices: usbip list -r localhost"
echo "  Restart all:        systemctl restart usbip-server.service usbip-huawei-bind.service usbip-huawei-monitor.service"
echo
echo "The system will now automatically:"
echo "  - Start usbipd daemon on boot"
echo "  - Detect and bind Huawei modems automatically"
echo "  - Re-bind devices after USB resets"
echo "  - Monitor for new Huawei devices continuously"
echo
