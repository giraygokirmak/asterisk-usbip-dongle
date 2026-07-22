#!/bin/sh
set -u

OUTPUT=${1:-"usbip-support-$(date -u +%Y%m%dT%H%M%SZ).txt"}
run() {
    title=$1
    shift
    {
        printf '\n===== %s =====\n' "$title"
        timeout -k 2 10 "$@" 2>&1 || printf '[command failed or timed out]\n'
    } >>"$OUTPUT"
}

: >"$OUTPUT"
run "date" date -u
run "kernel" uname -a
run "os release" sh -c 'cat /etc/os-release'
run "usbip version" usbip version
run "usbip ports" usbip port
run "USB modules" sh -c 'lsmod | grep -E "usbip|vhci"'
run "blocked tasks" ps -eo pid,ppid,stat,wchan:32,comm,args
run "kernel USB log" sh -c 'journalctl -k -b --no-pager | grep -Ei "usbip|vhci|ttyUSB|usb disconnect|hung task" | tail -300'
run "previous kernel USB log" sh -c 'journalctl -k -b -1 --no-pager | grep -Ei "usbip|vhci|ttyUSB|usb disconnect|hung task" | tail -300'
run "Docker versions" sh -c 'docker version; containerd --version'
run "Compose status" docker compose ps
run "USB/IP sidecar log" docker compose logs --no-color --tail=300 usbip-client
run "Asterisk log" docker compose logs --no-color --tail=200 asterisk
run "installed packages" sh -c 'dpkg-query -W "docker*" "containerd*" "linux-image*" "linux-modules*" "linux-tools*" "usbip*" 2>/dev/null'
run "recent apt history" sh -c 'zgrep -hE "^(Start-Date|Commandline|Upgrade:|Install:)" /var/log/apt/history.log* | tail -150'
chmod 600 "$OUTPUT"
echo "Support bundle written to $OUTPUT (review it before sharing)."
