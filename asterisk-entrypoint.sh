#!/bin/sh
set -eu
envsubst < /tmp/dongle.template > /etc/asterisk/dongle.conf
envsubst < /tmp/pjsip.template > /etc/asterisk/pjsip.conf
mkdir -p /var/run/fail2ban /var/log/asterisk
touch /var/log/asterisk/security.log
chown asterisk:asterisk /var/log/asterisk/security.log
chmod 660 /var/log/asterisk/security.log
/usr/bin/fail2ban-server -b -x start
exec /usr/sbin/asterisk -vvvdddf -T -W -U asterisk -p
