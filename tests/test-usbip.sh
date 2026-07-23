#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); pids=""
cleanup(){ for p in $pids;do kill "$p" 2>/dev/null||true;done; rm -rf "$T"; }
trap cleanup EXIT INT TERM
make_modprobe(){ printf '#!/bin/sh\nexit 0\n' >"$1/modprobe"; chmod +x "$1/modprobe"; }

# Imported devices remain ready even though a used device is absent from the export list.
A="$T/already"; mkdir -p "$A/bin" "$A/sys/bus/usb/devices/3-1/3-1:1.0/ttyUSB0" "$A/run"; printf '12d1\n' >"$A/sys/bus/usb/devices/3-1/idVendor"
cat >"$A/bin/usbip" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >>"$MOCK_CALLS"
case "$1 $2" in
 "port ") printf 'Port 00: <Port in Use>\n    3-1 -> usbip://192.0.2.10:3240/1-2\n';;
 "list -r") printf 'Exportable USB devices\n';;
esac
MOCK
chmod +x "$A/bin/usbip"; make_modprobe "$A/bin"
MOCK_CALLS="$A/calls" PATH="$A/bin:$PATH" SYSFS_ROOT="$A/sys" USBIP_RUN_DIR="$A/run" USB_IP=192.0.2.10 USBIP_ONCE=1 USBIP_HEALTH_INTERVAL=0 USBIP_RETRY_INITIAL=0 "$ROOT/usbip.sh"
grep -q '^readiness=ready$' "$A/run/status"; grep -q '^attached=1$' "$A/run/status"
if grep -q '^list -r' "$A/calls";then echo 'remote list queried despite healthy import' >&2;exit 1;fi

# Offline server degrades readiness while the supervisor remains live/healthy.
B="$T/offline"; mkdir -p "$B/bin" "$B/sys" "$B/run"
cat >"$B/bin/usbip" <<'MOCK'
#!/bin/sh
case "$1 $2" in "port ") exit 0;; "list -r") exit 124;; esac
MOCK
chmod +x "$B/bin/usbip"; make_modprobe "$B/bin"
PATH="$B/bin:$PATH" SYSFS_ROOT="$B/sys" USBIP_RUN_DIR="$B/run" USB_IP=192.0.2.10 USBIP_RETRY_INITIAL=5 USBIP_RETRY_MAX=5 USBIP_HEALTH_INTERVAL=1 "$ROOT/usbip.sh" & bp=$!;pids="$pids $bp"
i=0;while ! grep -q '^readiness=degraded$' "$B/run/status" 2>/dev/null;do sleep 1;i=$((i+1));[ $i -lt 10 ]||exit 1;done
PATH="$B/bin:$PATH" USBIP_RUN_DIR="$B/run" USBIP_RETRY_MAX=5 USBIP_HEALTH_INTERVAL=1 USB_IP=192.0.2.10 "$ROOT/usbip.sh" --health
kill "$bp";wait "$bp"||true;pids=""

# Attach may create the kernel import and tty before its CLI returns; it must not block the supervisor.
C="$T/hang"; mkdir -p "$C/bin" "$C/sys/bus/usb/devices" "$C/run"
cat >"$C/bin/usbip" <<'MOCK'
#!/bin/sh
case "$1 $2" in
 "list -r") printf 'Exportable USB devices\n - 1-2: Huawei modem (12d1:1506)\n';;
 "port ") if [ -e "$MOCK_ATTACHED" ];then printf 'Port 00: <Port in Use>\n    3-1 -> usbip://192.0.2.10:3240/1-2\n';fi;exit 0;;
 "attach -r") mkdir -p "$MOCK_SYSFS/bus/usb/devices/3-1/3-1:1.0/ttyUSB0";printf '12d1\n' >"$MOCK_SYSFS/bus/usb/devices/3-1/idVendor";: >"$MOCK_ATTACHED";echo $$ >"$MOCK_CHILD_PID";sleep 60;;
esac
MOCK
chmod +x "$C/bin/usbip"; make_modprobe "$C/bin"
MOCK_ATTACHED="$C/attached" MOCK_CHILD_PID="$C/child.pid" MOCK_SYSFS="$C/sys" PATH="$C/bin:$PATH" SYSFS_ROOT="$C/sys" USBIP_RUN_DIR="$C/run" USB_IP=192.0.2.10 USBIP_ONCE=1 USBIP_HEALTH_INTERVAL=0 USBIP_RETRY_INITIAL=0 USBIP_TTY_SETTLE_TIMEOUT=5 "$ROOT/usbip.sh"
grep -q '^readiness=ready$' "$C/run/status"; child=$(cat "$C/child.pid"); i=0; while kill -0 "$child" 2>/dev/null && [ $i -lt 5 ];do sleep 1;i=$((i+1));done; if kill -0 "$child" 2>/dev/null && ! ps -o stat= -p "$child" 2>/dev/null | grep -q ^Z;then echo 'attach child leaked' >&2;exit 1;fi

echo 'usbip reconciler fixtures: PASS'
