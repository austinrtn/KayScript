#!/bin/bash
set -euo pipefail
user="$USER" work_dir=""
udev_rule_path="/etc/udev/rules.d/99-usb-drive.rules"
on_usb_connected_path="/usr/local/bin/on-usb-connected.sh"

uid="$(id -u)"
home_dir="$HOME"
config_dir="${home_dir}/.config/systemd/user/"
service_path="${config_dir}kayscript.service"
script_dir="${home_dir}/.local/bin/"
script_path="${script_dir}kayscript.sh"
script_url="https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/KayScript.sh"

main(){
	local action="${1:---i}"

	if [[ "$action" == "--i" ]]; then
		install_kayscript	
	elif [[ "$action" == "--r" ]]; then
		uninstall
	elif [[ "$action" == "--p" ]]; then
		print_files
	else 
		echo "Invalid argument: $action" >&2
		echo "kayscript_install --i: Install"
		echo "kayscript_install --r: Uninstall"
		echo "kayscript_install --p: Print relevant files"
		exit 2
	fi
}

cleanup() {		
	status=$?
	rm -rf -- "$work_dir" || true
	trap - EXIT 
	exit "$status"
}

install_kayscript() {
	work_dir="$(mktemp -d)"
	trap cleanup EXIT
	cd "$work_dir"

	local udev_rule="udev_rule"
	local on_usb_connected="on_usb_connected"
	local service="service"
	local kayscript="KayScript.sh"
	local monitor=""
	local display_manager=""

	if [[ -f "$kayscript" ]]; then 
		chmod +x "$kayscript"
	else 
		echo "Downloading KayScript..."
		if curl --fail --silent --show-error --location --max-time 5 \
		"$script_url" -o "$kayscript"; then
			chmod +x "$kayscript"
			echo "Kayscript downloaded"
		else
			echo "Failed to download KayScript!"
			exit 1
		fi
	fi

	echo "Generating files..."
	cat > "$udev_rule" <<-EOF
		ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_BUS}=="usb", RUN+="${on_usb_connected_path}"
	EOF

	cat > "$on_usb_connected" <<-EOF
	#!/bin/sh
	/usr/bin/systemctl --machine=${user}@.host --user start kayscript.service
	EOF
	chmod +x "$on_usb_connected"

	if [[ -n "$(echo "$WAYLAND_DISPLAY")" ]]; then
		display_manager="Environment=WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
	elif [[ -n "$(echo "$XAUTHORITY")" ]]; then 
		display_manager="Environment=XAUTHORITY=${XAUTHORITY}"
		monitor="Environment=Display=:0"
	else 
		echo "Cannot find display manager"
		exit 1
	fi

	cat <<-EOF > "$service"
	[Unit]
	Description=Open terminal when USB storage is connected

	[Service]
	Type=oneshot
	${display_manager}
	${monitor}
	Environment=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
	Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus
	ExecStart=/usr/bin/alacritty -e /usr/bin/bash ${script_path}
	EOF

	# Move temp files to real paths
	echo "Installing Files..."
	mkdir -p "$config_dir" "$script_dir"

	sudo -v 
	sudo install -m 644 "$udev_rule" "$udev_rule_path"
	sudo install -m 755 "$on_usb_connected" "$on_usb_connected_path"
	install -m 644 "$service" "$service_path"
	install -m 755 "$kayscript" "$script_path"

	echo "Updating rules and services..."
	sudo udevadm control --reload-rules
	systemctl --user daemon-reload
	systemctl --user status "kayscript.service" | tail -n 2 || true

	echo "Installed!"
}

uninstall() {
	sudo -v
	sudo rm -f "$udev_rule_path"
	sudo rm -f "$on_usb_connected_path"
	sudo rm -f "$service_path"
	sudo rm -f "$script_path"

	sudo udevadm control --reload-rules
	systemctl --user daemon-reload
	echo "Uninstalled"
}

print_files() {	
	echo "###UDEV RULE###"
	echo "$udev_rule_path"
	if [[ -f "$udev_rule_path" ]]; then
		cat "$udev_rule_path"
	else 
		echo "File does not exist"
	fi
	echo "-----------------------"
	read

	echo "###ON_USB_CONNECTED###"
	echo "$on_usb_connected_path"
	if [[ -f "$on_usb_connected_path" ]]; then
		cat "$on_usb_connected_path"
	else 
		echo "File does not exist"
	fi
	echo "-----------------------"
	read

	echo "###SERVICE###"
	echo "$service_path"
	if [[ -f "$service_path" ]]; then
		cat "$service_path"
	else 
		echo "File does not exist"
	fi
	echo "-----------------------"
	read
	echo "###KAYSCRIPT###"
	echo "$script_path"
	if [[ -f "$script_path" ]]; then
		cat "$script_path"
	else 
		echo "File does not exist"
	fi
	read
	echo "###STATUS / LOGS###"
	command journalctl -u systemd-udevd --since "5 minutes ago" --no-pager
	command journalctl -u kayscript.service --since "5 minutes ago" --no-pager
	command systemctl --user status kayscript.service --no-pager -l
	echo "-----------------------"
}

main "$@"
