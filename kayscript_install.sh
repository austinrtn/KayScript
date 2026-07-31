#!/bin/bash
set -e
user="$USER"
udev_rule_path="/etc/udev/rules.d/99-usb-drive.rules"
on_usb_connected_path="/usr/local/bin/on-usb-connected.sh"

uid="$(id -u)"
home_dir="$HOME"
config_dir="${home_dir}/.config/systemd/user/"
service_path="${config_dir}kayscript.service"
script_dir="${home_dir}/.local/bin/"
script_path="${script_dir}kayscript.sh"

sudo -v

echo "Adding UDEV Rule"
sudo tee "$udev_rule_path" > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_BUS}=="usb", RUN+="${on_usb_connected_path}"
EOF

echo "Adding on-usb-connected script..."
sudo tee "$on_usb_connected_path" > /dev/null <<EOF
#!/bin/sh
/usr/bin/systemctl --machine=${user}@.host --user start kayscript.service
EOF

sudo chmod +x "$on_usb_connected_path"

echo "Adding service..."

if [[ ! -d "$config_dir" ]]; then
	mkdir -p "$config_dir"
fi

cat <<EOF > "$service_path"
[Unit]
Description=Open terminal when USB storage is connected

[Service]
Type=oneshot
Environment=WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
Environment=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus
ExecStart=/usr/bin/alacritty -e /usr/bin/bash ${script_path}
EOF

echo "Installing Script..."

if [[ ! -d "$script_dir" ]]; then
	mkdir -p "$script_dir"
fi

cat <<EOF > "$script_path"
read -rp "Hello World"
EOF
chmod +x "$script_path"

echo "Updating rules and services..."
sudo udevadm control --reload-rules
systemctl --user daemon-reload
systemctl --user status "kayscript.service" | tail -n 2

echo "Installed!"
