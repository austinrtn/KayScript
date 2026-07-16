#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    printf 'Run this with sudo:\n  sudo %s\n' "$0" >&2
    exit 1
fi

rule_file="/etc/udev/rules.d/99-usb-drive.rules"
handler="/usr/local/bin/on-usb-connected.sh"

cat > "$handler" <<'EOF'
#!/bin/sh
log_file="/tmp/test.txt"
err_file="/tmp/on-usb-connected.err"

/usr/bin/logger -t on-usb-connected "started DEVNAME=$DEVNAME DEVTYPE=$DEVTYPE ID_BUS=$ID_BUS ID_FS_LABEL=$ID_FS_LABEL"

/usr/bin/printf '%s DEVNAME=%s DEVTYPE=%s ID_BUS=%s ID_FS_LABEL=%s\n' "$(/usr/bin/date)" "$DEVNAME" "$DEVTYPE" "$ID_BUS" "$ID_FS_LABEL" >> "$log_file" 2>> "$err_file"

exit_code=$?
/usr/bin/logger -t on-usb-connected "finished exit_code=$exit_code"
exit "$exit_code"
EOF

chmod 755 "$handler"

cat > "$rule_file" <<'EOF'
ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/on-usb-connected.sh"
EOF

chmod 644 "$rule_file"

rm -f /tmp/test.txt /tmp/on-usb-connected.err

udevadm control --reload-rules

printf 'Installed:\n'
printf '  %s\n' "$rule_file"
printf '  %s\n' "$handler"
printf '\nNow unplug and replug the USB storage device, then run:\n'
printf '  cat /tmp/test.txt\n'
printf '  cat /tmp/on-usb-connected.err\n'
printf '  journalctl --since "5 minutes ago" --no-pager | grep on-usb-connected\n'
