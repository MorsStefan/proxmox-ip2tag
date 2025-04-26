#!/bin/bash

# https://github.com/MorsStefan/proxmox-ip2tag/
# Łukasz Dyś | Mors Stefan

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root. Please use sudo or log in as root." >&2
    exit 1
fi

#----------------------------------------------------------------------
function del_tmpd() { [ "$tmpd_safe_to_del" == "yes" ] && rm -rf "${tmpd}"; }

function download() {
    local rem="$1" loc="$2"
    [ -z "$2" ] && exit 1
    if ! curl -sSL "$rem" -o "$loc"; then
	echo "Error while downloading '$rem'. Exiting."
	del_tmpd
	exit 1
    fi
    if cat "$loc" | grep -qi '<!DOCTYPE html>'; then
        echo "File '$loc' is probably HTML file. Exiting."
	del_tmpd
        exit 1
    fi
    echo "File '${rem##*/}' has been downloaded to: '$loc'."
}

function copy() {
    local src="$1" dst="$2"
    [ -z "$2" ] && echo "[${FUNCNAME[0]}] Argument is missing. Exiting." && exit 1
    if ! yes | cp -f "$src" "$dst"; then
	echo "Error while copy: '$src' -> '$dst'"
	echo "Exiting."
	exit 1
    fi
}
#----------------------------------------------------------------------

echo
echo "Installing prox-ip2tag"
echo "----------------------"
echo

if [[ "$INSTALL_SOURCE" == "github" ]]; then
    echo "[Online installation]"
    echo
    if ! tmpd="$(mktemp -d)"; then
	echo "Error while creating temporary directory. Exiting."
	exit 1
    fi
    tmpd_safe_to_del='yes'
    download 'https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag'         "${tmpd}/prox-ip2tag"
    download 'https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.conf'    "${tmpd}/prox-ip2tag.conf"
    download 'https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.service' "${tmpd}/prox-ip2tag.service"
else
    echo "[Offline installation]"
    echo
    tmpd='.'
    tmpd_safe_to_del='no'
    for inst_file in 'prox-ip2tag' 'prox-ip2tag.conf' 'prox-ip2tag.service'; do
	if [ ! -f "${tmpd}/${inst_file}" ]; then
	    echo "File not exist: '$inst_file'"
	    echo "Exiting."
	    exit 1
	else
	    echo "File: '$inst_file' - ok"
	fi
    done
fi
echo

SCRIPT_SRC="${tmpd}/prox-ip2tag"
CONF_SRC="${tmpd}/prox-ip2tag.conf"
SERVICE_SRC="${tmpd}/prox-ip2tag.service"

CONF_DEST="/usr/local/etc/prox-ip2tag.conf"
SCRIPT_DEST="/usr/local/bin/prox-ip2tag"
SERVICE_DEST="/etc/systemd/system/prox-ip2tag.service"

if ! command -v jq &>/dev/null; then
    echo "The program 'jq' is not installed, but it is highly recommended."
    read -p "Shoud I install it? [Y/n] " reply
    reply=${reply:-Y}

    if [[ "$reply" =~ ^[Yy]$ ]]; then
	if apt-get install jq -y >/dev/null; then
	    echo "'jq' installation was successfull."
	else
	    echo "'jq' was not installed, something went wrong."
	fi
    else
	echo "'jq' installation was skipped."
    fi
    echo
fi

if [ -f "$SCRIPT_DEST" ]; then
    echo "File '$SCRIPT_DEST' already exists. "
    read -p "Overwrite? [Y/n] " reply
    reply=${reply:-Y}

    if [[ "$reply" =~ ^[Yy]$ ]]; then
	systemctl stop prox-ip2tag.service &>/dev/null
	copy "$SCRIPT_SRC" "$SCRIPT_DEST"
    else
        echo "Installation aborted by user."
	del_tmpd
	exit
    fi
else
    copy "$SCRIPT_SRC" "$SCRIPT_DEST"
    echo "File 'prox-ip2tag' was successfully copied to: '$SCRIPT_DEST'"
fi
echo

# Copy config file
if [ -f "$CONF_DEST" ]; then
    new_cfg_file="${CONF_DEST}_new"
    echo "Config file '$CONF_DEST' already exists."
    copy "$CONF_SRC" "$new_cfg_file"
    echo "It was not overwritten. A new version was saved as:"
    echo "-> '$new_cfg_file'"
else
    copy "$CONF_SRC" "$CONF_DEST"
    echo "Configuration file was successfully copied to: '$CONF_DEST'"
    show_cfg_info=1
fi
echo

echo "Creating systemd service: 'prox-ip2tag.service'"
systemctl stop prox-ip2tag.service &>/dev/null
copy "$SERVICE_SRC" "$SERVICE_DEST"
systemctl daemon-reload
echo

chown root:root "$SERVICE_DEST" "$SCRIPT_DEST" "$CONF_DEST"
chmod 644 "$SERVICE_DEST"; chmod 600 "$CONF_DEST"; chmod 700 "$SCRIPT_DEST"
del_tmpd

read -p "Enable and run prox-ip2tag.service [Y/n] " reply
reply=${reply:-Y}
if [[ "$reply" =~ ^[Yy]$ ]]; then
    systemctl enable prox-ip2tag.service
    systemctl start prox-ip2tag.service
    systemctl daemon-reload
    sleep 1
    if systemctl is-active --quiet prox-ip2tag.service; then
	echo "Service 'prox-ip2tag' is now active and running."
    else
	echo "Service 'prox-ip2tag' failed to start."
    fi
else
    echo "Don't forget to enable and start the service manually."
fi

echo
echo "Installation complete."
echo
if [ "$show_cfg_info" == "1" ]; then
    echo "Remember to modify the config file according to your needs:"
    echo "-> $CONF_DEST"
    echo
fi
