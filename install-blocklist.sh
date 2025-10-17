#!/bin/bash
set -Eeuo pipefail

mkdir -p /etc/ufw/backups
if [[ -f /etc/ufw/blocklist.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak blocklist.txtXXXXX)"
    mv /etc/ufw/blocklist.txt $bakfile
    echo "Backup of existing blocklist.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/blocklist-allow.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u blocklist-allow.txtXXXXX)"
    mv /etc/ufw/blocklist-allow.txt $bakfile
    echo "Backup of existing blocklist-allow.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/blocklist6-allow.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u blocklist6-allow.txtXXXXX)"
    mv /etc/ufw/blocklist6-allow.txt $bakfile
    echo "Backup of existing blocklist6-allow.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/after.init ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u after.initXXXXX)"
    mv /etc/ufw/after.init $bakfile
    echo "Backup of existing after.init stored to $bakfile"
fi
if [[ -f /etc/ufw/sources.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u sources.txtXXXXX)"
    mv /etc/ufw/sources.txt $bakfile
    echo "Backup of existing sources.txt stored to $bakfile"
fi
if [[ -f /etc/ufw/sources6.txt ]]; then
    bakfile="$(mktemp -p /etc/ufw/backups --suffix=.bak -u sources6.txtXXXXX)"
    mv /etc/ufw/sources6.txt $bakfile
    echo "Backup of existing sources.txt stored to $bakfile"
fi

cp sources.txt /etc/ufw/sources.txt
chown root:root /etc/ufw/sources.txt

cp sources6.txt /etc/ufw/sources6.txt
chown root:root /etc/ufw/sources6.txt

cp blocklist-allow.txt /etc/ufw/blocklist-allow.txt
chown root:root /etc/ufw/blocklist-allow.txt

cp blocklist6-allow.txt /etc/ufw/blocklist6-allow.txt
chown root:root /etc/ufw/blocklist6-allow.txt

cp update-blocklist-sources.sh /usr/local/sbin/update-blocklist-sources.sh
chown root:root /usr/local/sbin/update-blocklist-sources.sh
chmod +x /usr/local/sbin/update-blocklist-sources.sh

cp after.init /etc/ufw/
chown root:root /etc/ufw/after.init
chmod +x /etc/ufw/after.init

USE_UFW_RELOAD=true /usr/local/sbin/update-blocklist-sources.sh
ufw status verbose

# Inspect placement:
iptables -L ufw-before-input --line-numbers -v
iptables -L ufw-before-output --line-numbers -v
iptables -L ufw-before-forward --line-numbers -v
iptables -S BLOCKLIST
ipset list blocklist | head
