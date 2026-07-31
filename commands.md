# Useful commands:
- systemctl --user daemon-reload
    Reload user systemd

- systemctl --user start foo.service
    Test user service directly

- sudo udevadm control --reload-rules
    Reload udev rules

- sudo /path/to/usb-connected.sh
    Test the udev hanlder directly

- sudo udevadm --action=add --subsystem-match=block
    Trigger usb connection manually

- sudo udevadm monitor --udev --enviornment --subsystem-match=block
    Watch udev events live 

- journalctl -u systemd-udevd --since "5 minutes ago" --no-pager
    Check udev logs

- journalctl --user -u foo.service --since "5 minutes ago"
    Check user service logs 

- systemctl --user status foo.service --no-pager -l 
    Check service status 
