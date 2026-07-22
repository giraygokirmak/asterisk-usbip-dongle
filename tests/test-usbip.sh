#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/sys/bus/usb/devices/3-1/3-1:1.0/ttyUSB0" "$TEST_ROOT/run"
printf '12d1\n' >"$TEST_ROOT/sys/bus/usb/devices/3-1/idVendor"

cat >"$TEST_ROOT/bin/usbip" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >>"$MOCK_CALLS"
case "$1 $2" in
  "list -r") printf 'Exportable USB devices\n - 1-2: Huawei modem (12d1:1506)\n' ;;
  "port ") printf 'Port 00: <Port in Use>\n    3-1 -> usbip://192.0.2.10:3240/1-2\n' ;;
  *) exit 0 ;;
esac
MOCK
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/modprobe"
chmod +x "$TEST_ROOT/bin/usbip" "$TEST_ROOT/bin/modprobe"

MOCK_CALLS="$TEST_ROOT/calls" PATH="$TEST_ROOT/bin:$PATH" SYSFS_ROOT="$TEST_ROOT/sys" \
USBIP_RUN_DIR="$TEST_ROOT/run" USB_IP=192.0.2.10 USBIP_ONCE=1 \
USBIP_HEALTH_INTERVAL=0 USBIP_RETRY_INITIAL=0 "$ROOT/usbip.sh"

grep -q '^state=healthy$' "$TEST_ROOT/run/status"
grep -q '^attached=1$' "$TEST_ROOT/run/status"
if grep -q '^detach ' "$TEST_ROOT/calls"; then
    echo "healthy device was detached" >&2
    exit 1
fi
echo "usbip reconciler fixture: PASS"
