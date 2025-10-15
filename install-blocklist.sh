#!/bin/bash
set -Eeuo pipefail

sudo mkdir -p /etc/ufw/backups
if [[ -f /etc/ufw/blocklist.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u blocklist.txtXXXXX)"
    sudo mv /etc/ufw/blocklist.txt $bakfile
    echo "Backup of existing blocklist.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/blocklist-allow.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u blocklist-allow.txtXXXXX)"
    sudo mv /etc/ufw/blocklist-allow.txt $bakfile
    echo "Backup of existing blocklist-allow.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/blocklist6-allow.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u blocklist6-allow.txtXXXXX)"
    sudo mv /etc/ufw/blocklist6-allow.txt $bakfile
    echo "Backup of existing blocklist6-allow.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/after.init ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u after.initXXXXX)"
    sudo mv /etc/ufw/after.init $bakfile
    echo "Backup of existing after.init stored to $bakfile"
fi
sudo cp blocklist-allow.txt /etc/ufw/blocklist-allow.txt
sudo chown root:root /etc/ufw/blocklist-allow.txt

sudo cp blocklist6-allow.txt /etc/ufw/blocklist6-allow.txt
sudo chown root:root /etc/ufw/blocklist6-allow.txt

sudo cp update-blocklist-sources.sh /usr/local/sbin/update-blocklist-sources.sh
sudo chown root:root /usr/local/sbin/update-blocklist-sources.sh
sudo chmod +x /usr/local/sbin/update-blocklist-sources.sh

sudo cp after.init /etc/ufw/
sudo chown root:root /etc/ufw/after.init
sudo chmod +x /etc/ufw/after.init

sudo USE_UFW_RELOAD=true /usr/local/sbin/update-blocklist-sources.sh
sudo ufw status verbose

# Inspect placement:
sudo iptables -L ufw-before-input --line-numbers -v
sudo iptables -L ufw-before-output --line-numbers -v
sudo iptables -L ufw-before-forward --line-numbers -v
sudo iptables -S BLOCKLIST
sudo ipset list blocklist | head
