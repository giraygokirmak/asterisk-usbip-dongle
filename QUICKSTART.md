# Quick Start Guide

Get up and running with Asterisk USB/IP Dongle System in 15 minutes.

## Prerequisites Check

Before starting, ensure you have:
- [ ] Two Linux machines (or one machine for testing)
- [ ] Docker and Docker Compose installed on Asterisk host
- [ ] Root/sudo access on both machines
- [ ] At least one Huawei USB dongle
- [ ] Network connectivity between machines

## Part 1: USB/IP Server (5 minutes)

**On the machine with physical USB dongles:**

### 1. Install USB/IP
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install linux-tools-generic usbip

# Fedora/RHEL
sudo dnf install usbip-utils

# Arch Linux
sudo pacman -S usbip
```

### 2. Clone and Install
```bash
git clone https://github.com/giraygokirmak/asterisk-usbip-dongle.git
cd asterisk-usbip-dongle/dongleserver
chmod +x install.sh
sudo ./install.sh
```

### 3. Verify
```bash
# Check services are running
sudo systemctl status usbip-server.service

# List shared devices
usbip list -r localhost
```

### 4. Configure Firewall
```bash
# Note your server IP (e.g., 192.168.1.100)
ip addr show

# Allow Asterisk server to connect (replace with your Asterisk server IP)
sudo ufw allow from 192.168.1.200 to any port 3240
```

## Part 2: Asterisk Container (10 minutes)

**On the machine that will run Asterisk:**

### 1. Install Docker (if not already installed)
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin

# Log out and back in for group changes to take effect
```

### 2. Clone Repository
```bash
git clone https://github.com/giraygokirmak/asterisk-usbip-dongle.git
cd asterisk-usbip-dongle
```

### 3. Find Your Dongle's Bus ID
```bash
# First, install usbip client tools on this machine too
sudo apt install linux-tools-generic usbip

# List devices on USB/IP server (replace with your server IP)
usbip list -r 192.168.1.100

# Output will look like:
# Exportable USB devices
# ======================
#  - 1-2: Huawei Technologies Co., Ltd. (12d1:1506)
#
# Note the bus ID (1-2 in this example)
```

### 4. Configure Environment
```bash
# Edit env.sh
nano env.sh

# Set these values:
export IMEI1=35XXXXXXXXXXXXX        # Your dongle's IMEI (find with AT+CGSN)
export LOCAL_NET=192.168.1.0/24     # Your network
export USB_IP=192.168.1.100         # USB/IP server IP from Part 1
export USB_BIND=1-2                 # Bus ID from step 3
export EXTEN_PASS=ChooseStrongPassword

# Save and exit (Ctrl+X, Y, Enter)
```

### 5. Start Asterisk
```bash
# Load environment variables
source env.sh

# Build and start
docker-compose up -d

# Watch logs
docker-compose logs -f
```

### 6. Verify Asterisk is Working
```bash
# Access Asterisk CLI
docker exec -it asterisk-dongle asterisk -rvvv

# Check dongle status (inside CLI)
dongle show devices

# You should see your dongle listed with status "Free" or "Initialized"
# Exit CLI with: exit
```

## Quick Test

### Make a Test Call

1. **Configure a SIP Client:**
   - Username: `100` (or as configured in pjsip.template)
   - Password: Value of `EXTEN_PASS` from env.sh
   - Server: IP address of your Asterisk container
   - Port: `5060`

2. **Make a Call:**
   - Dial a mobile number through the dongle
   - Format: `9XXXXXXXXXX` (depending on your extensions.conf)

### Send a Test SMS

```bash
# Access Asterisk CLI
docker exec -it asterisk-dongle asterisk -rvvv

# Send SMS (replace number with actual recipient)
dongle sms dongle0 +1234567890 "Test message from Asterisk"
```

## Common First-Time Issues

### "USB device not found" in Asterisk logs
```bash
# Check if USB/IP connection is working
docker exec -it asterisk-dongle usbip port

# Should show attached device. If empty:
docker exec -it asterisk-dongle ls -l /dev/ttyUSB*

# If no ttyUSB devices, restart the container
docker-compose restart
```

### "Permission denied" for ttyUSB
```bash
# The usbip.sh script should handle this, but if issues persist:
docker exec -it asterisk-dongle bash
chmod 777 /dev/ttyUSB*
asterisk -rx "dongle reload now"
```

### Dongle shows "Not connected" in Asterisk
```bash
# Check if SIM card is inserted and PIN is disabled
# Access dongle CLI:
docker exec -it asterisk-dongle asterisk -rx "dongle cmd dongle0 AT+CPIN?"

# Should return: "+CPIN: READY"
# If it asks for PIN, you need to disable PIN on your SIM card
```

### Can't connect from SIP client
```bash
# Check if Asterisk is listening
docker exec -it asterisk-dongle netstat -tulpn | grep 5060

# Check Docker host firewall
sudo ufw allow 5060/udp
sudo ufw allow 5061/tcp

# Test from client machine
nc -zv <asterisk-ip> 5060
```

## Next Steps

✅ **Success?** Great! Now check out:
- [Main README](README.md) for detailed configuration options
- [Asterisk Configuration](asterisk-config/) for customizing dialplan
- [Security Guide](#-security-considerations) in main README

❌ **Having issues?** See:
- [Troubleshooting Guide](README.md#-troubleshooting) in main README
- [USB/IP Server Docs](dongleserver/README.md) for server-side issues
- [Open an Issue](https://github.com/giraygokirmak/asterisk-usbip-dongle/issues)

## Quick Commands Reference

### Asterisk Container
```bash
docker-compose up -d              # Start
docker-compose down               # Stop
docker-compose logs -f            # View logs
docker exec -it asterisk-dongle asterisk -rvvv  # Access CLI
docker-compose restart            # Restart
```

### USB/IP Server
```bash
sudo systemctl status usbip-server.service      # Check status
sudo journalctl -u usbip-huawei-monitor.service -f  # View logs
usbip list -r localhost           # List shared devices
sudo systemctl restart usbip-server.service    # Restart
```

### Useful Asterisk CLI Commands
```bash
dongle show devices               # Show dongle status
core show channels               # Show active calls
pjsip show endpoints             # Show SIP endpoints
core reload                      # Reload configuration
```

## Getting Help

1. **Read the logs:**
   ```bash
   docker-compose logs -f
   sudo tail -f /var/log/usbip-huawei.log
   ```

2. **Check the full documentation:**
   - [Main README](README.md)
   - [USB/IP Server README](dongleserver/README.md)

3. **Ask for help:**
   - [Open an issue](https://github.com/giraygokirmak/asterisk-usbip-dongle/issues)
   - Include logs and your configuration (remove sensitive data!)

---

**Estimated total time:** 15-20 minutes for first-time setup

Good luck! 🚀
