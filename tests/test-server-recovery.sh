#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.."&&pwd); T=$(mktemp -d);trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/sys/bus/usb/devices/2-1" "$T/sys/bus/usb/drivers/usbip-host/2-1" "$T/run"
echo 12d1 >"$T/sys/bus/usb/devices/2-1/idVendor";echo 2 >"$T/sys/bus/usb/drivers/usbip-host/2-1/usbip_status"
cat >"$T/bin/usbip" <<'MOCK'
#!/bin/bash
case "$1" in
 unbind) rm -rf "$SYSFS_ROOT/bus/usb/drivers/usbip-host/$3";;
 bind) mkdir -p "$SYSFS_ROOT/bus/usb/drivers/usbip-host/$3";echo 1 >"$SYSFS_ROOT/bus/usb/drivers/usbip-host/$3/usbip_status";;
 list) echo "  2-1: Huawei modem (12d1:140c)";;
esac
MOCK
chmod +x "$T/bin/usbip"
PATH="$T/bin:$PATH" SYSFS_ROOT="$T/sys" USBIP_STATE_DIR="$T/run" "$ROOT/dongleserver/usbip-huawei-recover.sh" 2-1
grep -q '^1$' "$T/sys/bus/usb/drivers/usbip-host/2-1/usbip_status"
echo 'usbip server recovery fixture: PASS'
