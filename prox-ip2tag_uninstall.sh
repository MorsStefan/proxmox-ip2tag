#!/usr/bin/env bash

# https://github.com/MorsStefan/proxmox-ip2tag/
# Łukasz Dyś | Mors Stefan
# 2026-01-21 | ver 0.0.2

#------------------------------------------------------------------------------

echo "Stop and disable prox-ip2tag.service"
systemctl stop prox-ip2tag.service
systemctl disable prox-ip2tag.service
sleep 1
systemctl kill prox-ip2tag.service &>/dev/null
echo

echo "Removing prox-ip2tag files from disk"
rm -fv /etc/systemd/system/prox-ip2tag.service
rm -fv /usr/local/bin/prox-ip2tag

if [ -f "/usr/local/etc/prox-ip2tag.conf" ]; then
    echo "Creating config file backup"
    cp -av "/usr/local/etc/prox-ip2tag.conf" "/usr/local/etc/prox-ip2tag.conf[$(date +'%F_%T')]"
    rm -fv "/usr/local/etc/prox-ip2tag.conf"
fi
echo
echo "Prox-ip2tag removed"
echo
