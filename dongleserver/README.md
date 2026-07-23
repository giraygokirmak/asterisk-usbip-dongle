# Huawei USB/IP server

This directory installs a systemd-managed USB/IP server for Huawei modems.

## Components

- `usbip-server.service`: foreground `usbipd` daemon.
- `usbip-huawei-bind.service`: idempotent one-shot export reconciler.
- `usbip-huawei-bind.timer`: runs reconciliation every 30 seconds.
- `99-usbip-huawei.rules`: requests reconciliation after Huawei USB hotplug.
- `usbip-huawei-recover.sh`: locked and verified stale-session recovery.

The legacy `usbip-huawei-monitor.service` and `--monitor` process are unsupported and removed by `install.sh`.

## Install

```bash
cd dongleserver
sudo ./install.sh
systemctl status usbip-server.service usbip-huawei-bind.timer --no-pager
usbip list -r 127.0.0.1
```

A device is exportable when its `usbip_status` is `1`. While a healthy client owns it, status is `2` and it normally disappears from `usbip list -r`.

## Stale-session recovery

A stale session is confirmed when the server has `usbip_status=2` and an established client TCP connection, while the client has no `usbip port` entry and no modem TTY devices. Stop the client reconciler first, then run:

```bash
sudo usbip-huawei-recover 2-1.5.2.1
```

The command locks recovery, validates the Huawei vendor, performs bounded unbind/bind, then requires `usbip_status=1` and remote export visibility.

## Optional automatic recovery

Automatic recovery is disabled by default because a reset interrupts active modem traffic. To enable it after validating the thresholds, create `/etc/default/usbip-huawei`:

```bash
USBIP_AUTO_RECOVER_STALE=1
USBIP_STALL_THRESHOLD=20
USBIP_STALL_WINDOW="120 seconds ago"
USBIP_RECOVERY_COOLDOWN=300
```

Then run `sudo systemctl daemon-reload`. Recovery is considered only for status `2` devices with enough matching kernel endpoint-stall messages and respects the cooldown.

## Diagnostics

```bash
usbip list -l
usbip list -r 127.0.0.1
cat /sys/bus/usb/drivers/usbip-host/BUSID/usbip_status
sudo ss -ntp 'sport = :3240'
journalctl -u usbip-server.service -u usbip-huawei-bind.service
journalctl -k --since '-5 min' | grep -Ei 'usbip|stall|reset'
```
