#!/usr/bin/env bash
# prox-ip2tag - Installation Script
# Author: Łukasz Dyś (Mors Stefan)
# https://github.com/MorsStefan/proxmox-ip2tag

set -euo pipefail

AUTO_START="${AUTO_START:-yes}"
SKIP_DEPENDENCIES="${SKIP_DEPENDENCIES:-no}"

SCRIPT_URL='https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag'
CONF_URL='https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.conf'
SERVICE_URL='https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.service'

SCRIPT_DEST='/usr/local/bin/prox-ip2tag'
CONF_DEST='/usr/local/etc/prox-ip2tag.conf'
SERVICE_DEST='/etc/systemd/system/prox-ip2tag.service'

#------------------------------------------------------------------------------
download() {
    local url="$1" dest="$2"
    curl -fsSL "$url" -o "$dest" || {
        echo "Error downloading: $url"
        del_tmpd
        exit 1
    }
    if grep -qi '<!DOCTYPE html>' "$dest"; then
        echo "Invalid file (HTML): $url"
        del_tmpd
        exit 1
    fi
    echo "Downloaded: ${url##*/}"
}

copy() {
    local src="$1" dst="$2"
    yes | cp -f "$src" "$dst" || {
        echo "Copy failed: $src -> $dst"
        exit 1
    }
}

del_tmpd() {
    if [[ "$tmpd_safe_to_del" == "yes" ]] && [[ -n "$tmpd" ]] && [[ "$tmpd" != "." ]]; then
        rm -rf "$tmpd"
    fi
}
#------------------------------------------------------------------------------

[[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }

echo "Installing proxmox-ip2tag"
echo "-------------------------"

# Determine source
if [[ "${INSTALL_SOURCE:-}" == "github" ]]; then
    echo "[Online installation]"
    tmpd="$(mktemp -d)"
    tmpd_safe_to_del="yes"
    download "$SCRIPT_URL"  "$tmpd/prox-ip2tag"
    download "$CONF_URL"    "$tmpd/prox-ip2tag.conf"
    download "$SERVICE_URL" "$tmpd/prox-ip2tag.service"
else
    echo "[Offline installation]"
    tmpd="."
    tmpd_safe_to_del="no"
    for file in 'prox-ip2tag' 'prox-ip2tag.conf' 'prox-ip2tag.service'; do
        if [[ ! -f "${tmpd}/${file}" ]]; then
            echo "Missing file: '${file}'"
            exit 1
        else
            echo "Found: '${file}'"
        fi
    done
fi

SCRIPT_SRC="${tmpd}/prox-ip2tag"
CONF_SRC="${tmpd}/prox-ip2tag.conf"
SERVICE_SRC="${tmpd}/prox-ip2tag.service"

# Optional dependency
if [[ "$SKIP_DEPENDENCIES" != "yes" ]]; then
    echo "Installing dependency: jq"
    apt-get update -qq
    if apt-get install -y jq >/dev/null; then
        echo "jq installed successfully."
    else
        echo "Warning: failed to install jq. Continuing without it."
    fi
else
    echo "Skipping installation of jq (SKIP_DEPENDENCIES=yes)."
fi

# Script file
systemctl stop prox-ip2tag.service >/dev/null 2>&1 || true
copy "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod 700 "$SCRIPT_DEST"
echo "Installed: $SCRIPT_DEST"

# Config file
if [[ -f "$CONF_DEST" ]]; then
    new_conf="${CONF_DEST}_new"
    copy "$CONF_SRC" "$new_conf"
    chmod 600 "$new_conf"
    echo "Config exists. New copy saved as: $new_conf"
else
    copy "$CONF_SRC" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    echo "Installed config: $CONF_DEST"
fi

# Service file
copy "$SERVICE_SRC" "$SERVICE_DEST"
chmod 644 "$SERVICE_DEST"
echo "Installed service: $SERVICE_DEST"

systemctl daemon-reexec
systemctl daemon-reload

if [[ "$AUTO_START" == "yes" ]]; then

    systemctl enable prox-ip2tag.service
    systemctl restart prox-ip2tag.service
    if systemctl is-active --quiet prox-ip2tag.service; then
        echo "Service 'prox-ip2tag' is now active and running."
    else
        echo "Service 'prox-ip2tag' failed to start."
    fi
else
    echo "Service 'prox-ip2tag' not started (AUTO_START=no)."
fi

del_tmpd
echo "-------------------------"
echo "Installation complete."
