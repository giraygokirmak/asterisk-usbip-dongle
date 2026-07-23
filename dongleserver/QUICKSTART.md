# Quick start

```bash
sudo apt install usbip linux-tools-$(uname -r) linux-modules-extra-$(uname -r)
cd dongleserver
sudo ./install.sh
usbip list -r 127.0.0.1
```

Check services:

```bash
systemctl status usbip-server.service usbip-huawei-bind.timer --no-pager
journalctl -u usbip-server.service -u usbip-huawei-bind.service -f
```

Recover a confirmed stale Huawei session after stopping the remote client:

```bash
sudo usbip-huawei-recover BUSID
```

Do not install or start the removed `usbip-huawei-monitor.service`.
