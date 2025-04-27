#!/usr/bin/env bash

# v0.0.1-alpha
# Not intended for production use!!

# Usage:
#   ./prox-tags-backup.sh backup [backup_file]
#   ./prox-tags-backup.sh restore <backup_file>

cdate=$(date '+%F_%H-%m-%S')

function die() {
    echo "[Error] $*" >&2
    exit 1
}

function backup() {
    local backup_file
    backup_file="tags.backup_${cdate}.bak"
    [ -n "$1" ] && backup_file="$1"
    [ -f "$backup_file" ] && die "File '$backup_file' already exists."

    echo "# prox-tags-backup: $(date '+%F %T')" > "$backup_file"
    echo "#" >> "$backup_file"

    # LXCs
    while read -r vmid name _; do
	local tags
	tags=$(pct config "$vmid" 2>/dev/null | awk -F': ' '/^tags:/ {print $2}')
	echo "[Info] Backing up LXC $vmid tags -> $tags"
	echo "lxc:$vmid:$tags" >> "$backup_file"
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1, $2}')

    # VMs
    while read -r vmid name; do
	local tags
	tags=$(qm config "$vmid" 2>/dev/null | awk -F': ' '/^tags:/ {print $2}')
	echo "[Info] Backing up VM $vmid tags -> $tags"
	echo "vm:$vmid:$tags" >> "$backup_file"
    done < <(qm list 2>/dev/null | awk 'NR>1 {print $1, $2}')

    echo "[Info] Backup saved to $backup_file"
}

function validate_backup_format() {
    local file="$1"
    local row
    while IFS= read -r row; do
	[[ "$row" =~ ^# ]] && continue
	[[ -z "$row" ]] && continue
	if ! [[ "$row" =~ ^(lxc|vm):[0-9]+:.*$ ]]; then
	    echo "[Error] Invalid format in backup file '$file' on line: $row" >&2
	    exit 1
	fi
    done < "$file"
}

function restore() {
    local backup_file
    [[ -z "$1" ]] && die "Usage: $0 restore <backup_file>"
    backup_file="$1"
    [[ ! -f "$backup_file" ]] && die "Backup file '$backup_file' not found."

    validate_backup_format "$backup_file"

    while IFS=: read -r type vmid tags; do
	[[ "$type" =~ ^# ]] && continue
	[[ -z "$type" ]] && continue

	if [[ "$type" == "lxc" ]]; then
	    pct set "$vmid" -tags "$tags" &>/dev/null && \
	    echo "[OK] Restored LXC $vmid tags -> $tags" || echo "[Error] Failed restoring LXC $vmid"
	elif [[ "$type" == "vm" ]]; then
	    qm set "$vmid" -tags "$tags" &>/dev/null && \
	    echo "[OK] Restored VM  $vmid tags -> $tags" || echo "[Error] Failed restoring VM  $vmid"
	else
	    echo "[Warn] Unknown type '$type' in backup line"
	fi
    done < "$backup_file"
}

# main
case "$1" in
    backup)  backup  "$2" ;;
    restore) restore "$2" ;;
    *) die "Usage: $0 {backup [backup_file] | restore <backup_file>}" ;;
esac
