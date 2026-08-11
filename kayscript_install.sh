#!/bin/bash
set -euo pipefail
user="$USER" work_dir=""

uid="$(id -u)"
project_dir="${HOME}/.local/share/KayScript/" # Where project files are installed 
config_dir="${HOME}/.config/systemd/user/"  # Where service is installed 
gh_url="https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/"

# UDEV RULE
udev_rule_path="/etc/udev/rules.d/99-usb-drive.rules"
udev_url="${gh_url}99-usb-connected.sh"

# ROOT SERVICE
root_service_apth="/etc/systemd/system/kayscript-usb.service"
root_service_url=""

# KAYSCRIPT SERVICE 
service_path="/etc/systemd/system/kayscript.service" # Path to service 
service_url="${gh_url}kayscript.service"

script_path="${project_dir}KayScript.sh"
script_url="${gh_url}KayScript.sh"

py_app_path="${project_dir}app.py" # Python App path
py_app_url="${gh_url}app.py"

req_json_path="${project_dir}requirements.json" # Bash / Pip Requirements 
req_json_url="${gh_url}requirements.json"

### NEED TO INSTALL A WAY TO PUSH TO GH 

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

	local sudoers_path="/etc/sudoers.d/kayscript"
	local udev_rule="udev_rule"
	local on_usb_connected="on-usb-connected"
	local root_service="kayscript.service"
	local kayscript="KayScript.sh"
	local py_app="app.py"
	local req_json="requirements.json"
	local monitor=""
	local display_manager=""

	download "$service_url" "$service" || exit 1
	download "$udev_url" "$udev_rule" || exit 1
	download "$script_url" "$kayscript" || exit 1
	download "$py_app_url" "$py_app" || exit 1
	download "$req_json_url" "$req_json" || exit 1

	echo "Downloads Complete!"

	chmod +x "$on_usb_connected" "$kayscript"

	# udev_rule: Replace placeholders with variables 
	sed \
		-e "s|__ROOT_SERVICE__|${service}|g" \
		"$udev_rule" > "${udev_rule}.tmp" 
	mv "${udev_rule}.tmp" "$udev_rule"

	# kayscript.service: Replace placeholders with variables 
	sed \
		-e "s|__SCRIPT_PATH__|${script_path}|g" \
		"$service" > "${service}.tmp"
	mv "${service}.tmp" "$service"

	# Move temp files to real paths
	echo "Installing Files..."
	mkdir -p "$config_dir" "$project_dir"
	sudo mkdir -p /mnt/

	sudo -v 
	sudo install -m 644 "$udev_rule" "$udev_rule_path"
	sudo install -o root -g root -m 644 "$service" "$service_path"
	sudo install -m 755 "$on_usb_connected" "$on_usb_connected_path"
	install -m 755 "$py_app" "$py_app_path"
	install -m 755 "$req_json" "$req_json_path"
	sudo install -o root -g root -m 0755 "$kayscript" "$script_path"

	rule="$user ALL=(root) NOPASSWD: $script_path"	
	tmp_rule="$(mktemp)"
	printf "%s\n" "$rule" > "$tmp_rule"
	command visudo -cf "$tmp_rule"

	sudo install -o root -g root -m 0440 "$tmp_rule" "$sudoers_path"
	
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

	if curl --fail --silent --show-error --location --max-time 15 \
		"$url" -o "$file_name"; then
		echo "$file_name downloaded"
		return 0
	else
		echo "Failed to download $file_name"
		return 1
	fi
}

main "$@"
