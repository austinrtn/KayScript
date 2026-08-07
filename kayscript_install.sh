#!/bin/bash
set -euo pipefail
user="$USER" work_dir=""

uid="$(id -u)"
project_dir="${HOME}/.local/share/KayScript/" # Where project files are installed 
config_dir="${HOME}/.config/systemd/user/"  # Where service is installed 

udev_rule_path="/etc/udev/rules.d/99-usb-drive.rules"
on_usb_connected_path="/usr/local/bin/on-usb-connected.sh"
service_path="${config_dir}kayscript.service" # Path to service 
script_path="${project_dir}KayScript.sh"
py_app_path="${project_dir}app.py" # Python App path
req_json_path="${project_dir}requirements.json" # Bash / Pip Requirements 

gh_url="https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/"
udev_url="${gh_url}99-usb-connected.sh"
on_usb_connected_url="${gh_url}on_usb_connected.sh"
service_url="${gh_url}kayscript.service"
script_url="${gh_url}KayScript.sh"
py_app_url="${gh_url}app.py"
req_json_url="${gh_url}requirements.json"

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

install_kayscript() {
	work_dir="$(mktemp -d)"
	trap cleanup EXIT
	cd "$work_dir"

	local udev_rule="udev_rule"
	local on_usb_connected="on-usb-connected"
	local service="kayscript.service"
	local kayscript="KayScript.sh"
	local py_app="app.py"
	local req_json="requirements.json"
	local monitor=""
	local display_manager=""

	download "$service_url" "$service" || exit 1
	download "$udev_url" "$udev_rule" || exit 1
	download "$on_usb_connected_url" "$on_usb_connected" || exit 1
	download "$script_url" "$kayscript" || exit 1
	download "$py_app_url" "$py_app" || exit 1
	download "$req_json_url" "$req_json" || exit 1

	echo "Downloads Complete!"

	chmod +x "$on_usb_connected" "$kayscript"

	# udev_rule: Replace placeholders with variables 
	sed \
		-e "s|__USB_CONNECTED_PATH__|${on_usb_connected_path}|g" \
		"$udev_rule" > "${udev_rule}.tmp" 
	mv "${udev_rule}.tmp" "$udev_rule"

	# on_usb_connected: Replace placeholders with variables 
	sed \
		-e "s|__USER__|${USER}|g" \
		"$on_usb_connected" > "${on_usb_connected}.tmp"
	mv "${on_usb_connected}.tmp" "$on_usb_connected"

	# Get Envirnment variables and append to service file 
	local runtime_dir="/run/user/$uid"
	if [[ -n "$(echo "$WAYLAND_DISPLAY")" ]]; then
		display_manager="Environment=WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
	elif [[ -n "$(echo "$XAUTHORITY")" ]]; then 
		display_manager="Environment=XAUTHORITY=${XAUTHORITY}"
		monitor="Environment=Display=:0"
	else 
		echo "Cannot find display manager"
		exit 1
	fi

	cat >> "$service" <<-EOF
	$display_manager
	$monitor
	EOF

	# kayscript.service: Replace placeholders with variables 
	sed \
		-e "s|__SCRIPT_PATH__|${script_path}|g" \
		-e "s|__XDG_RUNTIME_DIR__|${runtime_dir}|g" \
		-e "s|__UID__|${uid}|g" \
		"$service" > "${service}.tmp"
	mv "${service}.tmp" "$service"

	# Move temp files to real paths
	echo "Installing Files..."
	mkdir -p "$config_dir" "$project_dir"

	sudo -v 
	sudo install -m 644 "$udev_rule" "$udev_rule_path"
	sudo install -m 755 "$on_usb_connected" "$on_usb_connected_path"
	install -m 644 "$service" "$service_path"
	install -m 755 "$kayscript" "$script_path"
	install -m 755 "$py_app" "$py_app_path"
	install -m 755 "$req_json" "$req_json_path"

	ln -sfn "$udev_rule_path" "$project_dir"
	ln -sfn "$on_usb_connected_path" "$project_dir"
	ln -sfn "$service_path" "$project_dir"

	echo "Updating rules and services..."
	sudo udevadm control --reload-rules
	systemctl --user daemon-reload
	systemctl --user status "kayscript.service" | tail -n 2 || true

	echo "Installing Python Virtual Envirnment..."
	cd "$project_dir"
	python -m venv .venv

	echo "Installed!"
}

uninstall() {
	sudo -v
	sudo rm -f "$udev_rule_path"
	sudo rm -f "$on_usb_connected_path"
	sudo rm -f "$service_path"
	sudo rm -f "$py_app_path"
	sudo rm -rf "$project_dir"

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
	echo "###PYTHON APP###"
	echo "$py_app_path"
	if [[ -f "$py_app_path" ]]; then
		cat "$py_app_path"
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

cleanup() {
        status=$?
        rm -rf -- "$work_dir" || true
        trap - EXIT
        exit "$status"
}

download() {
	url="$1"
	file_name="$2"

	if curl --fail --silent --show-error --location --max-time 5 \
		"$url" -o "$file_name"; then
		echo "$file_name downloaded"
		return 0
	else
		echo "Failed to download $file_name"
		return 1
	fi
}

main "$@"
