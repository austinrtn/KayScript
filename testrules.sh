#!/bin/sh
set -eu

log_file="/tmp/test.txt"
rule_file="/etc/udev/rules.d/99-usb-drive.rules"
handler="/usr/local/bin/on-usb-connected.sh"

rm -f "$log_file"

udevadm control --reload-rules
udevadm trigger --action=add --subsystem-match=block

printf '%s\n' "Rule:"
cat "$rule_file"

printf '\n%s\n' "Handler:"
cat "$handler"

printf '\n%s\n' "Handler output:"
if [ -f "$log_file" ]; then
    cat "$log_file"
else
    printf 'No %s was written.\n' "$log_file"
fi

printf '\n%s\n' "Recent udev log lines:"
journalctl -u systemd-udevd --since "2 minutes ago" --no-pager | grep on-usb-connected || true

journalctl -u systemd-udevd --since "5 minutes ago"
