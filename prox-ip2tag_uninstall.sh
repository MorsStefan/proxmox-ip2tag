#!/usr/bin/env bash

# https://github.com/MorsStefan/proxmox-ip2tag/
# Łukasz Dyś | Mors Stefan
# 2026-01-21 | ver 0.9.1

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "[Error] This script must be run as root."; exit 1; }

# Files to delete
F_TO_DEL=(
    '/usr/local/bin/prox-ip2tag'
    '/usr/local/etc/prox-ip2tag.conf'
    '/etc/systemd/system/prox-ip2tag.service'
)

#------------------------------------------------------------------------------
# Remove IP tags from VMs and LXCs (default).
# Values: [ yes | no ]
KEEP_IP_TAGS="${KEEP_IP_TAGS:-no}"

if [[ ! "$KEEP_IP_TAGS" =~ ^(yes|no)$ ]]; then
    echo "[Error] Bad value for: KEEP_IP_TAGS -> '$KEEP_IP_TAGS'"
    exit 1
fi
#------------------------------------------------------------------------------

function valid_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    for i in ${ip//./ }; do
        [[ "${#i}" -gt 1 && "${i:0:1}" == 0 ]] && return 1
        [[ "$i" -gt 255 ]] && return 1;
    done
    return 0
}

function remove_ip_tag () {
    if ! [[ "$1" == "lxc" || "$1" == "vm" ]]; then
	echo "[Error] Bad input type: $1"
	exit 1
    fi
    local lxc_vm=() tags tag tags_new=() type_txt cmd_out el_id
    local type="$1"

    if [ "$type" == "vm" ]; then
	cmd='qm'
	type_txt='VM'
    else
	cmd='pct'
	type_txt='LXC'
    fi

    if ! cmd_out="$( "$cmd" list )"; then
	echo "[Error] Failed to read $type_txt list. Exiting."
	exit 1
    fi
    mapfile -t lxc_vm < <(echo "$cmd_out" | awk 'NR>1 {print $1}')

    for el_id in "${lxc_vm[@]}"; do
	tags_new=()

	if ! cmd_out="$( "$cmd" config "$el_id" )"; then
	    echo "[Error] Failed to read $type $el_id tag list. Exiting."
	    exit 1
	fi
	mapfile -t tags < <(echo "$cmd_out" | sed -n 's/^tags: //p' | tr ';' '\n')

	for tag in "${tags[@]}"; do
	    ! valid_ipv4 "$tag" && tags_new+=("$tag")
	done

	echo "   $type_txt id $el_id [cur tags]: ${tags[*]}"
	echo "   $type_txt id $el_id [new tags]: ${tags_new[*]}"
	if ! "$cmd" set "${el_id}" -tags "$(IFS=";"; echo "${tags_new[*]}")"; then
	    echo "[Error] Failed to set new tags for $type_txt id $el_id. Exiting." && exit 1
	fi
    done

    if [ -z "${el_id:-}" ]; then
	echo "   no $type_txt found"
    fi
}

function remove_file() {
    if [ -z "${1:-}" ]; then
	echo "[Error] No filename given. Exiting."
	exit 1
    fi
    local f="$1"
    if [ -f "$f" ]; then
	if rm -f "$f"; then
	    echo "   File removed: '$f'"
	else
	    echo "[Error] Failed to remove: '$f'. Exiting."
	    exit 1
	fi
    else
	echo "   File already removed: '$f'"
    fi
}

#------------------------------------------------------------------------------

echo "Uninstalling proxmox-ip2tag"
echo "---------------------------"

systemctl daemon-reload || true

if systemctl cat prox-ip2tag.service &>/dev/null; then
    echo "Disabling prox-ip2tag.service..."
    if ! systemctl disable prox-ip2tag.service; then
	echo "[Warning] Failed to disable service."
    fi

    echo "Stopping prox-ip2tag.service..."
    if ! systemctl stop prox-ip2tag.service; then
	echo "[Warning] Failed to stop service."
    fi
else
    echo "Service prox-ip2tag.service already uninstalled."
fi

# Config file backup
if [ -f "/usr/local/etc/prox-ip2tag.conf" ]; then
    echo
    echo "Creating config file backup..."
    b_file="/usr/local/etc/prox-ip2tag.conf-$(date +'%F_%T')"
    if cp -a "/usr/local/etc/prox-ip2tag.conf" "$b_file"; then
	echo "   Backup created: '$b_file'"
    else
	echo "[Error] Failed to create backup file '$b_file'. Exiting."
	exit 1
    fi
fi

echo
echo "Removing proxmox-ip2tag files..."
for delete_me in "${F_TO_DEL[@]}"; do
    remove_file "$delete_me"
done

if [ "$KEEP_IP_TAGS" == 'no' ]; then
    echo
    echo "Removing IP tags from containers..."
    remove_ip_tag "lxc"
    echo

    echo "Removing IP tags from virtual machines..."
    remove_ip_tag "vm"
fi

systemctl daemon-reload || true

echo "---------------------------"
echo "Uninstallation completed."
echo
