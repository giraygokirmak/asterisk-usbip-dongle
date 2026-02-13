# Quick Start Guide - USB/IP Huawei Auto-Bind

## Installation (5 minutes)

### 1. Install USB/IP Tools
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install linux-tools-generic usbip

# Fedora/RHEL
sudo dnf install usbip-utils

# Arch
sudo pacman -S usbip
```

### 2. Run Installer
```bash
chmod +x install.sh
sudo ./install.sh
```

That's it! The system is now running.

## Verify Installation

```bash
# Check services
sudo systemctl status usbip-server.service
sudo systemctl status usbip-huawei-monitor.service

# Or use validation script
chmod +x validate.sh
sudo ./validate.sh
```

## View Bound Devices

```bash
# See what's being shared
usbip list -r localhost
```

## Connect from Client

```bash
# On client machine
sudo modprobe vhci-hcd
usbip list -r <server-ip>
sudo usbip attach -r <server-ip> -b <busid>
```

## Common Commands

```bash
# View logs in real-time
sudo journalctl -u usbip-huawei-monitor.service -f
sudo tail -f /var/log/usbip-huawei.log

# Restart everything
sudo systemctl restart usbip-server.service usbip-huawei-bind.service

# Manual trigger
sudo /usr/local/bin/usbip-huawei-bind.sh
```

## Troubleshooting

**No devices bound?**
```bash
# Check if Huawei devices are detected
usbip list -l | grep -i huawei

# Check logs
sudo tail -20 /var/log/usbip-huawei.log
```

**Service not starting?**
```bash
# Reload and retry
sudo systemctl daemon-reload
sudo systemctl restart usbip-server.service
```

**Need to unbind?**
```bash
sudo usbip unbind -b <busid>
```

## Files Overview

- `usbip-huawei-bind.sh` - Main script (auto-detects & binds devices)
- `usbip-server.service` - Runs usbipd daemon
- `usbip-huawei-bind.service` - Binds devices at startup
- `usbip-huawei-monitor.service` - Monitors continuously
- `99-usbip-huawei.rules` - Auto-triggers on USB events
- `install.sh` - Installs everything
- `uninstall.sh` - Removes everything
- `validate.sh` - Tests your setup
- `README.md` - Full documentation

## How It Works

1. **Boot**: Services start, usbipd runs, Huawei modems are detected and bound
2. **Hot-plug**: New Huawei device → udev triggers → device auto-binds
3. **USB reset**: Monitor detects unbind → re-binds within 10 seconds

## Uninstall

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

For detailed documentation, see **README.md**
