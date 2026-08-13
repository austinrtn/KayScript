#!/usr/bin/env bash

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$script_dir"

# file names
requirements="requirements.json"
app="app.py"
devices="devices"

# parse json arrays into bash readable data
mapfile -t system_reqs < <(jq -r '.system[]' "$requirements") # machine package requirements 
mapfile -t pip_reqs < <(jq -r '.pip[]' "$requirements") # pip package requirements 
pip_reqs_count="${#pip_reqs[@]}"

# determine package manager command 
pkg_manager_cmd=""
if command -v apt >/dev/null 2>&1; then 
	pkg_manager_cmd=(apt-get install)
elif command -v dnf >/dev/null 2>&1; then 
	pkg_manager_cmd=(dnf install)
elif command -v pacman >/dev/null 2>&1; then 
	pkg_manager_cmd=(pacman -s --needed)
fi

# missing bash pacakges stored here 
missing_pkgs=()

# loop through each package and check to see if the command is available
for pkg in "${system_reqs[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        missing_pkgs+=("$pkg")
        missing_count+=1
    fi
done

# install missing packages if necessary
if (( ${#missing_pkgs[@]} > 0 )); then
	echo "missing packages: ${missing_pkgs[@]}"

	install_sys_pkgs=""
	if [[ -n "$pkg_manager_cmd" ]]; then 
		read -r -p "would you like to install? [y/n]: " install_sys_pkgs	
		if [[ "$install_sys_pkgs" == "y" ]]; then 
	    		sudo "${pkg_manager_cmd[@]}" -- "${missing_pkgs[@]}"
		fi
	elif [[ -z "$pkg_manager_cmd" || "$install_sys_pkgs" != "y" ]]; then
		echo "please install these pacakges and try again." 
		exit 1
	fi
fi

# activate the python virtual enviornment
source .venv/bin/activate

# check if pip packages are installed 
has_reqs=false
if (( pip_reqs_count > 0 )); then
    # query which packages need to be installed, returns as json array `install`.  check if the array is greater than 0 
    # and if so, has_reqs is set to true
    if python -m pip install --dry-run --quiet --report - "${pip_reqs[@]}" |
        jq -e '.install | length == 0' >/dev/null
    then 
        has_reqs=true
    fi

    # install missing requirements if neccessary
    if [[ $has_reqs == false ]]; then
        echo "installing pip requirements..."
        python -m pip install "${pip_reqs[@]}" >/dev/null
    fi
fi

if [[ ! -f "$app" ]]; then 
	touch "$app"
fi
if [[ ! -f "$devices" ]]; then 
	touch "$devices"
fi

#open program  
clear
python "$app"
