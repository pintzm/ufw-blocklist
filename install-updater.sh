#!/bin/bash
cp ufw-blocklist-update.service /etc/systemd/system/ufw-blocklist-update.service
cp ufw-blocklist-update.timer /etc/systemd/system/ufw-blocklist-update.timer
chown root:root /etc/systemd/system/ufw-blocklist-update.service /etc/systemd/system/ufw-blocklist-update.timer
systemctl daemon-reload
systemctl enable --now ufw-blocklist-update.timer
# Try once now:
systemctl start ufw-blocklist-update.service
