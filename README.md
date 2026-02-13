# Asterisk USB/IP Dongle System

A complete, production-ready solution for running Asterisk PBX with Huawei GSM dongles over USB/IP. This system enables you to physically separate your USB dongles from your Asterisk server, providing flexibility for distributed deployments, cloud hosting, or containerized environments.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## 🎯 Overview

This project provides two integrated components:

1. **Asterisk Docker Container** - A containerized Asterisk PBX with chan_dongle support, fail2ban security, and automatic USB/IP client connection
2. **USB/IP Dongle Server** - An automated system for sharing Huawei USB modems over the network with hot-plug support, automatic recovery, and continuous monitoring

## ✨ Features

### Asterisk Container
- 🐳 **Docker-based deployment** - Easy installation and portability
- 📞 **Chan_dongle support** - Built from source with correct Asterisk version matching
- 🔒 **Fail2ban integration** - Automatic protection against brute-force attacks
- 🔌 **Automatic USB/IP client** - Self-healing connection to remote dongles
- ⚙️ **Template-based configuration** - Environment variable driven setup
- 🌐 **PJSIP support** - Modern SIP channel driver configuration

### USB/IP Server
- 🔄 **Automatic detection** - Finds all connected Huawei modems
- 🚀 **Auto-binding on boot** - Devices are shared immediately at startup
- 🔌 **Hot-plug support** - Detects and shares newly connected devices
- 🔧 **USB reset recovery** - Automatically re-binds devices after USB bus resets
- 👁️ **Continuous monitoring** - Checks device status every 10 seconds
- 🛡️ **Duplicate prevention** - Smart checking to avoid binding conflicts
- 📝 **Comprehensive logging** - All actions logged to systemd journal and file
- ⚡ **Zero-touch operation** - Runs completely hands-free once installed

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USB/IP Server                            │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Physical Huawei Dongles (USB)                         │    │
│  └────────────┬───────────────────────────────────────────┘    │
│               │                                                 │
│  ┌────────────▼────────────────────────────────────────────┐   │
│  │  usbip-server.service (usbipd daemon)                   │   │
│  │  + usbip-huawei-bind.service (auto-bind at boot)        │   │
│  │  + usbip-huawei-monitor.service (continuous monitoring) │   │
│  │  + 99-usbip-huawei.rules (udev hot-plug detection)      │   │
│  └────────────┬────────────────────────────────────────────┘   │
└───────────────┼─────────────────────────────────────────────────┘
                │
                │ Network (TCP Port 3240)
                │
┌───────────────▼─────────────────────────────────────────────────┐
│                    Asterisk Docker Container                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  usbip.sh (client connection script)                     │  │
│  │  ↓                                                        │  │
│  │  Virtual USB devices (/dev/ttyUSB*)                      │  │
│  │  ↓                                                        │  │
│  │  chan_dongle (Asterisk module)                           │  │
│  │  ↓                                                        │  │
│  │  Asterisk PBX                                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  fail2ban (security monitoring)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### For USB/IP Server (Dongle Host)
- Linux server with physical USB ports
- Supported OS: Ubuntu/Debian, Fedora/RHEL, or Arch Linux
- Root/sudo access
- One or more Huawei USB modems
- Network connectivity to Asterisk server

### For Asterisk Container
- Docker and Docker Compose installed
- Network access to USB/IP server
- Sufficient resources (minimum 1GB RAM, 2 CPU cores recommended)

## 🚀 Installation

### Part 1: USB/IP Server Setup (Dongle Host)

This server physically hosts your Huawei USB dongles and shares them over the network.

#### Step 1: Install USB/IP Tools

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

#### Step 2: Install the USB/IP Auto-Bind System

```bash
# Navigate to the dongleserver directory
cd dongleserver

# Make scripts executable
chmod +x install.sh

# Run the installer
sudo ./install.sh
```

The installer will:
- Copy the binding script to `/usr/local/bin/`
- Install systemd service files
- Install udev rules for hot-plug detection
- Enable and start all services
- Create log file at `/var/log/usbip-huawei.log`

#### Step 3: Verify USB/IP Server Installation

```bash
# Check service status
sudo systemctl status usbip-server.service
sudo systemctl status usbip-huawei-monitor.service

# Or use the validation script
chmod +x validate.sh
sudo ./validate.sh

# View currently shared devices
usbip list -r localhost
```

#### Step 4: Configure Firewall (if enabled)

```bash
# Allow USB/IP port from your Asterisk server
sudo ufw allow from <asterisk-server-ip> to any port 3240

# Or for iptables
sudo iptables -A INPUT -p tcp --dport 3240 -s <asterisk-server-ip> -j ACCEPT
```

### Part 2: Asterisk Container Setup

#### Step 1: Clone the Repository

```bash
git clone https://github.com/giraygokirmak/asterisk-usbip-dongle.git
cd asterisk-usbip-dongle
```

#### Step 2: Configure Environment Variables

Edit the `env.sh` file with your configuration:

```bash
#!/bin/bash
export IMEI1=35XXXXXXXXXXXXX              # Your first dongle's IMEI
export IMEI2=35XXXXXXXXXXXXX              # Your second dongle's IMEI (if applicable)
export LOCAL_NET=192.168.1.0/24           # Your local network in CIDR notation
export USB_IP=192.168.1.100               # IP address of your USB/IP server
export USB_BIND=1-2                       # Bus ID of the dongle to bind (get from 'usbip list -r <USB_IP>')
export PUBLIC_IP=$(dig +short txt ch whoami.cloudflare @1.1.1.1 | tr -d '"')
export EXTEN_PASS=your_secure_password    # Password for SIP extensions
```

**To find your dongle's Bus ID:**
```bash
# Run this from the Asterisk server (must have usbip client installed)
usbip list -r <USB_IP_server_address>

# Example output:
# Exportable USB devices
# ======================
#  - 1-2: Huawei Technologies Co., Ltd. (12d1:1506)
#           : USB 2.0 Hub
#
# Use "1-2" as your USB_BIND value
```

#### Step 3: Customize Asterisk Configuration (Optional)

The `asterisk-config` directory contains template files that are populated with environment variables:

- **dongle.template** - Chan_dongle configuration
- **pjsip.template** - PJSIP endpoints and transports
- **extensions.template** - Dialplan configuration

Edit these files if you need custom dialplan logic or additional dongle settings.

#### Step 4: Build and Start the Container

```bash
# Load environment variables
source env.sh

# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f
```

#### Step 5: Verify Installation

```bash
# Check container status
docker ps

# Access Asterisk CLI
docker exec -it asterisk-dongle asterisk -rvvv

# In Asterisk CLI, check dongle status:
dongle show devices

# You should see your dongle(s) listed and their status
```

## ⚙️ Configuration Details

### Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `IMEI1` | IMEI of first Huawei dongle | `35XXXXXXXXXXXXX` |
| `IMEI2` | IMEI of second Huawei dongle | `35XXXXXXXXXXXXX` |
| `LOCAL_NET` | Local network in CIDR notation | `192.168.1.0/24` |
| `USB_IP` | IP address of USB/IP server | `192.168.1.100` |
| `USB_BIND` | Bus ID of dongle to bind | `1-2` |
| `PUBLIC_IP` | Public IP (auto-detected) | `203.0.113.1` |
| `EXTEN_PASS` | SIP extension password | `SecureP@ssw0rd!` |

### Dongle Configuration

The dongle configuration supports multiple devices. To add more dongles:

1. Uncomment the `[dongle1]` section in `asterisk-config/dongle.template`
2. Add the IMEI as an environment variable
3. Adjust the USB binding script if needed

### Fail2ban Configuration

Fail2ban is pre-configured to protect SIP ports:
- **Ports protected:** 5060, 5061
- **Max retries:** 3 attempts
- **Ban time:** 999 hours
- **Find time:** 10 minutes

Edit `jail.local` to adjust these settings.

## 🔧 Usage

### Asterisk Container Commands

```bash
# Start the container
docker-compose up -d

# Stop the container
docker-compose down

# Restart the container
docker-compose restart

# View logs
docker-compose logs -f

# Access Asterisk CLI
docker exec -it asterisk-dongle asterisk -rvvv

# Rebuild after configuration changes
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### USB/IP Server Commands

```bash
# Check service status
sudo systemctl status usbip-server.service
sudo systemctl status usbip-huawei-monitor.service

# View real-time logs
sudo journalctl -u usbip-huawei-monitor.service -f
sudo tail -f /var/log/usbip-huawei.log

# List shared devices
usbip list -r localhost

# Manually trigger binding
sudo systemctl start usbip-huawei-bind.service

# Restart all services
sudo systemctl restart usbip-server.service usbip-huawei-monitor.service

# Manual script execution
sudo /usr/local/bin/usbip-huawei-bind.sh
```

### Asterisk CLI Commands

```bash
# Show dongle status
dongle show devices

# Reload dongle configuration
dongle reload now

# Send SMS
dongle sms dongle0 +1234567890 "Test message"

# Show calls
core show calls

# Show PJSIP endpoints
pjsip show endpoints
```

## 🐛 Troubleshooting

### Asterisk Container Issues

#### Container Won't Start
```bash
# Check Docker logs
docker-compose logs asterisk

# Verify environment variables
source env.sh
env | grep -E "IMEI|USB_IP|USB_BIND"

# Check if ports are available
sudo netstat -tulpn | grep -E "5060|3240"
```

#### Dongle Not Detected in Asterisk
```bash
# Access container
docker exec -it asterisk-dongle bash

# Check USB devices
ls -l /dev/ttyUSB*

# Check if USB/IP client is running
ps aux | grep usbip

# Check usbip connection status
usbip port

# Try manual connection
usbip attach -r $USB_IP -b $USB_BIND
```

#### Fail2ban Not Working
```bash
# Check fail2ban status in container
docker exec -it asterisk-dongle fail2ban-client status

# Check if security log exists
docker exec -it asterisk-dongle ls -l /var/log/asterisk/security.log

# View fail2ban logs
docker exec -it asterisk-dongle tail -f /var/log/fail2ban.log
```

### USB/IP Server Issues

#### Devices Not Binding
```bash
# Check if dongles are detected
usbip list -l | grep -i huawei
lsusb | grep -i huawei

# Check service status
sudo systemctl status usbip-server.service
sudo systemctl status usbip-huawei-monitor.service

# View detailed logs
sudo journalctl -u usbip-huawei-bind.service -n 50
sudo tail -50 /var/log/usbip-huawei.log

# Try manual binding
sudo /usr/local/bin/usbip-huawei-bind.sh
```

#### Service Won't Start
```bash
# Check permissions
ls -la /usr/local/bin/usbip-huawei-bind.sh

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Check kernel modules
sudo modprobe usbip-host
lsmod | grep usbip
```

#### Hot-Plug Not Working
```bash
# Monitor udev events
sudo udevadm monitor --environment --udev
# Then plug/unplug a USB device

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Network Issues

#### Cannot Connect to USB/IP Server
```bash
# Test connectivity
ping <USB_IP_server>

# Check if port 3240 is open
telnet <USB_IP_server> 3240

# From Asterisk container, test usbip
docker exec -it asterisk-dongle usbip list -r $USB_IP
```

#### Firewall Blocking Connection
```bash
# On USB/IP server, check firewall rules
sudo ufw status
sudo iptables -L -n | grep 3240

# Temporarily disable firewall for testing (not recommended for production)
sudo ufw disable
```

## 🔒 Security Considerations

### USB/IP Security
⚠️ **Important:** USB/IP has no built-in encryption or authentication!

**Recommendations:**
1. **Use on trusted networks only** - Never expose USB/IP to the internet
2. **Firewall protection** - Restrict port 3240 to specific IP addresses
3. **VPN/SSH tunneling** - For remote access, use encrypted tunnels
4. **Network segmentation** - Isolate USB/IP traffic on a dedicated VLAN

**Example SSH Tunnel:**
```bash
# On Asterisk server, create SSH tunnel to USB/IP server
ssh -L 3240:localhost:3240 user@usbip-server

# Then use localhost as USB_IP
export USB_IP=localhost
```

### Asterisk Security
1. **Change default passwords** - Always use strong passwords in `env.sh`
2. **Fail2ban is enabled** - Automatic protection against brute force
3. **Network restrictions** - Configure `LOCAL_NET` appropriately
4. **Regular updates** - Keep the base Docker image updated

### Container Security
```bash
# Run security scan
docker scan asterisk-dongle

# Check for updates
docker-compose pull
docker-compose up -d
```

## 📁 Project Structure

```
.
├── asterisk-config/              # Asterisk configuration templates
│   ├── dongle.template          # Chan_dongle configuration
│   ├── extensions.template      # Dialplan (extensions.conf)
│   └── pjsip.template          # PJSIP configuration
├── dongleserver/                # USB/IP server component
│   ├── 99-usbip-huawei.rules   # Udev rules for hot-plug
│   ├── install.sh              # Installation script
│   ├── uninstall.sh            # Uninstallation script
│   ├── usbip-huawei-bind.sh    # Main binding script
│   ├── usbip-huawei-bind.service    # Boot-time binding service
│   ├── usbip-huawei-monitor.service # Continuous monitoring service
│   ├── usbip-server.service    # USB/IP daemon service
│   ├── validate.sh             # Validation script
│   ├── QUICKSTART.md           # Quick start guide for USB/IP server
│   └── README.md               # Detailed USB/IP server documentation
├── asterisk-filter.conf         # Fail2ban filter for Asterisk
├── docker-compose.yaml          # Docker Compose configuration
├── Dockerfile                   # Asterisk container definition
├── env.sh                       # Environment variables template
├── jail.local                   # Fail2ban jail configuration
├── usbip.sh                     # USB/IP client connection script
├── LICENSE                      # GPL v3 License
└── README.md                    # This file
```

## 🔄 Updating

### Update Asterisk Container
```bash
# Pull latest base image
docker-compose pull

# Rebuild
docker-compose build --no-cache

# Restart with new image
docker-compose down
docker-compose up -d
```

### Update USB/IP Server
```bash
cd dongleserver

# Run uninstall
sudo ./uninstall.sh

# Pull latest code
git pull

# Reinstall
sudo ./install.sh
```

## 🗑️ Uninstallation

### Remove Asterisk Container
```bash
# Stop and remove container
docker-compose down

# Remove image
docker rmi asterisk-usbip-dongle_asterisk

# Remove volumes (optional - deletes all data!)
docker volume prune
```

### Remove USB/IP Server
```bash
cd dongleserver
chmod +x uninstall.sh
sudo ./uninstall.sh
```

This will stop and disable all services, remove systemd files, udev rules, and scripts. Log files are kept for reference.

## 📚 Additional Resources

- [Asterisk Documentation](https://wiki.asterisk.org/)
- [Chan_dongle GitHub](https://github.com/wdoekes/asterisk-chan-dongle)
- [USB/IP Documentation](https://www.kernel.org/doc/html/latest/usb/usbip_protocol.html)
- [Fail2ban Documentation](https://www.fail2ban.org/)
- [Docker Documentation](https://docs.docker.com/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

### Development Setup
```bash
# Clone repository
git clone https://github.com/giraygokirmak/asterisk-usbip-dongle.git
cd asterisk-usbip-dongle

# Make changes
# Test locally

# Submit PR
```

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Asterisk](https://www.asterisk.org/) - The Open Source PBX
- [Chan_dongle](https://github.com/wdoekes/asterisk-chan-dongle) - GSM modem driver for Asterisk
- [USB/IP Project](https://usbip.sourceforge.net/) - USB over IP
- [Fail2ban](https://www.fail2ban.org/) - Intrusion prevention system

## 📧 Support

For issues and questions:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Review [closed issues](https://github.com/giraygokirmak/asterisk-usbip-dongle/issues?q=is%3Aissue+is%3Aclosed)
3. Open a [new issue](https://github.com/giraygokirmak/asterisk-usbip-dongle/issues/new)

---

**Note:** This system is designed for technical users familiar with Linux, Docker, and VoIP systems. Always test in a development environment before deploying to production.
