#!/bin/bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    echo "ERROR: run this installer as root"
    exit 1
fi

for command in usbip usbipd timeout systemctl udevadm modprobe; do
    command -v "$command" >/dev/null || { echo "ERROR: missing required command: $command"; exit 1; }
done
usbip version >/dev/null 2>&1 || {
    echo "ERROR: usbip does not run with kernel $(uname -r)"
    echo "Ubuntu/Debian: install usbip linux-tools-$(uname -r) linux-modules-extra-$(uname -r)"
    exit 1
}
modinfo usbip-host >/dev/null 2>&1 || modinfo usbip_host >/dev/null 2>&1 || {
    echo "ERROR: usbip-host kernel module is unavailable for $(uname -r)"
    exit 1
}

# Remove the legacy continuous monitor before installing the timer model.
systemctl disable --now usbip-huawei-monitor.service 2>/dev/null || true
rm -f /etc/systemd/system/usbip-huawei-monitor.service
install -m 0755 usbip-huawei-bind.sh /usr/local/bin/usbip-huawei-bind.sh
install -m 0644 usbip-server.service /etc/systemd/system/usbip-server.service
install -m 0644 usbip-huawei-bind.service /etc/systemd/system/usbip-huawei-bind.service
install -m 0644 usbip-huawei-bind.timer /etc/systemd/system/usbip-huawei-bind.timer
install -m 0644 99-usbip-huawei.rules /etc/udev/rules.d/99-usbip-huawei.rules

systemctl daemon-reload
udevadm control --reload-rules
systemctl enable --now usbip-server.service
sleep 2
systemctl start usbip-huawei-bind.service
systemctl enable --now usbip-huawei-bind.timer

echo "USB/IP Huawei export reconciliation installed."
systemctl --no-pager --full status usbip-server.service || true
systemctl --no-pager --full status usbip-huawei-bind.timer || true
echo "Logs: journalctl -u usbip-server.service -u usbip-huawei-bind.service"
