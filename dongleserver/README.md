# USB/IP Huawei Modem Auto-Bind System

A fail-proof systemd-based solution for automatically sharing Huawei USB modems over the network using USB/IP.

## Features

✅ **Automatic Detection**: Automatically detects all connected Huawei modems  
✅ **Auto-Binding**: Binds devices automatically on system boot  
✅ **Hot-Plug Support**: Detects and binds newly connected devices via udev rules  
✅ **USB Reset Recovery**: Automatically re-binds devices after USB bus resets  
✅ **Continuous Monitoring**: Background service monitors device status every 10 seconds  
✅ **Duplicate Prevention**: Checks if devices are already bound before attempting to bind  
✅ **Error Recovery**: Automatic restart on failures with exponential backoff  
✅ **Comprehensive Logging**: All actions logged to systemd journal and /var/log/usbip-huawei.log  

## Components

### 1. `usbip-huawei-bind.sh` - Main Binding Script
- Scans for Huawei modems using the command: `usbip list -l | awk '/busid/ {id=$3} /Huawei/ {print id}' | paste -sd ","`
- Checks which devices are already bound
- Binds only unbound devices
- Supports both single-run and continuous monitoring modes
- Implements proper locking to prevent concurrent execution

### 2. `usbip-server.service` - USB/IP Daemon Service
- Starts the usbipd daemon (`usbipd -D -4`)
- Loads required kernel modules
- Auto-restarts on failure
- Logs to systemd journal

### 3. `usbip-huawei-bind.service` - Initial Binding Service
- Runs once at startup after usbip-server is ready
- Binds all detected Huawei modems
- Triggered by udev rules when devices are connected

### 4. `usbip-huawei-monitor.service` - Continuous Monitoring Service
- Runs the binding script in monitor mode
- Checks every 10 seconds for:
  - New Huawei devices
  - Unbound devices that should be bound
  - USB/IP daemon health
- Auto-restarts if crashed

### 5. `99-usbip-huawei.rules` - Udev Rule
- Triggers binding service when:
  - Huawei devices (vendor ID 12d1) are connected
  - Any USB device is added
  - USB bus changes/resets occur

## Installation

### Prerequisites

Install USB/IP tools:

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install linux-tools-generic usbip
```

**Fedora/RHEL:**
```bash
sudo dnf install usbip-utils
```

**Arch Linux:**
```bash
sudo pacman -S usbip
```

### Install the System

1. Download or clone all files to a directory
2. Make the installation script executable:
   ```bash
   chmod +x install.sh
   ```
3. Run the installer as root:
   ```bash
   sudo ./install.sh
   ```

The installer will:
- Copy scripts to `/usr/local/bin/`
- Install systemd service files to `/etc/systemd/system/`
- Install udev rules to `/etc/udev/rules.d/`
- Enable and start all services
- Create log file at `/var/log/usbip-huawei.log`

## Usage

### Check Service Status

```bash
# Check all services
sudo systemctl status usbip-server.service
sudo systemctl status usbip-huawei-bind.service
sudo systemctl status usbip-huawei-monitor.service
```

### View Logs

```bash
# Real-time systemd logs
sudo journalctl -u usbip-server.service -f
sudo journalctl -u usbip-huawei-bind.service -f
sudo journalctl -u usbip-huawei-monitor.service -f

# Script logs
sudo tail -f /var/log/usbip-huawei.log
```

### List Bound Devices

```bash
# List locally bound devices
usbip list -l

# List devices being shared
usbip list -r localhost
```

### Manual Operations

```bash
# Manually trigger binding
sudo systemctl start usbip-huawei-bind.service

# Restart all services
sudo systemctl restart usbip-server.service usbip-huawei-bind.service usbip-huawei-monitor.service

# Manually run the binding script
sudo /usr/local/bin/usbip-huawei-bind.sh

# Run in monitor mode manually
sudo /usr/local/bin/usbip-huawei-bind.sh --monitor
```

### Connect from Client

On the client machine:

```bash
# Load kernel module
sudo modprobe vhci-hcd

# List available devices
usbip list -r <server-ip>

# Attach a device (use busid from list command)
sudo usbip attach -r <server-ip> -b <busid>

# Example:
# sudo usbip attach -r 192.168.1.100 -b 1-2
```

## Troubleshooting

### Devices Not Binding

1. Check if Huawei modems are detected:
   ```bash
   usbip list -l | grep -i huawei
   ```

2. Check if usbipd is running:
   ```bash
   sudo systemctl status usbip-server.service
   ps aux | grep usbipd
   ```

3. Check logs for errors:
   ```bash
   sudo journalctl -u usbip-huawei-bind.service -n 50
   sudo tail -50 /var/log/usbip-huawei.log
   ```

4. Try manual binding:
   ```bash
   sudo /usr/local/bin/usbip-huawei-bind.sh
   ```

### Service Won't Start

1. Check for permission issues:
   ```bash
   ls -la /usr/local/bin/usbip-huawei-bind.sh
   # Should be executable: -rwxr-xr-x
   ```

2. Verify systemd files:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
   ```

3. Check for kernel module:
   ```bash
   sudo modprobe usbip-host
   lsmod | grep usbip
   ```

### USB Reset Detection Not Working

1. Monitor udev events:
   ```bash
   sudo udevadm monitor --environment --udev
   # Then plug/unplug a USB device
   ```

2. Test udev rule manually:
   ```bash
   sudo udevadm test /sys/bus/usb/devices/1-2
   ```

3. Reload udev rules:
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

## Security Considerations

⚠️ **Important**: USB/IP shares devices over the network with no encryption or authentication by default.

**Recommendations:**
- Use only on trusted networks
- Configure firewall to restrict access to port 3240
- Consider using VPN or SSH tunneling for remote access
- The `-4` flag restricts usbipd to IPv4 only

**Firewall Configuration:**
```bash
# Allow from specific IP only
sudo ufw allow from 192.168.1.0/24 to any port 3240

# Or use iptables
sudo iptables -A INPUT -p tcp --dport 3240 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3240 -j DROP
```

## Uninstallation

To remove all components:

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

This will:
- Stop and disable all services
- Remove systemd service files
- Remove udev rules
- Remove the binding script
- Keep log files for reference (can be manually deleted)

## File Locations

- **Script**: `/usr/local/bin/usbip-huawei-bind.sh`
- **Services**: `/etc/systemd/system/usbip-*.service`
- **Udev Rule**: `/etc/udev/rules.d/99-usbip-huawei.rules`
- **Logs**: `/var/log/usbip-huawei.log`
- **Lock File**: `/var/run/usbip-huawei.lock`

## How It Works

### Boot Sequence
1. `usbip-server.service` starts and launches `usbipd -D -4`
2. `usbip-huawei-bind.service` runs and binds all detected Huawei modems
3. `usbip-huawei-monitor.service` starts continuous monitoring

### Hot-Plug Sequence
1. User connects a Huawei USB modem
2. Kernel generates USB add event
3. Udev rule matches the event
4. `usbip-huawei-bind.service` is triggered
5. Script detects and binds the new device

### USB Reset Recovery
1. USB subsystem resets (power event, driver reload, etc.)
2. Devices become unbound
3. Monitor service detects unbound devices within 10 seconds
4. Devices are automatically re-bound

## Customization

### Change Vendor/Product

Edit `usbip-huawei-bind.sh` and modify the awk pattern:

```bash
# For different vendor:
DEVICE_BUSBIDS=$(usbip list -l | awk '/busid/ {id=$3} /YourVendor/ {print id}' | paste -sd "," -)

# For specific product ID:
DEVICE_BUSBIDS=$(usbip list -l | awk '/busid/ {id=$3} /12d1:1506/ {print id}' | paste -sd "," -)
```

### Change Monitoring Interval

Edit `usbip-huawei-bind.sh` and change the sleep value in monitor mode:

```bash
# Change from 10 seconds to 30 seconds
sleep 30
```

Or modify the service to use a systemd timer instead.

### Add Email Notifications

Install `mailutils` and add to the script:

```bash
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
    if [[ "$1" == ERROR* ]] || [[ "$1" == FATAL* ]]; then
        echo "$1" | mail -s "USB/IP Alert" admin@example.com
    fi
}
```

## License

This is free and unencumbered software released into the public domain.

## Support

For issues, please check:
1. System logs: `journalctl -xe`
2. USB/IP documentation: `man usbip`
3. Verify USB device is visible: `lsusb`
