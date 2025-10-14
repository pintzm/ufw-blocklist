#!/bin/bash
sudo cp ufw-blocklist-update.service /etc/systemd/system/ufw-blocklist-update.service
sudo cp ufw-blocklist-update.timer /etc/systemd/system/ufw-blocklist-update.timer
sudo chown root:root /etc/systemd/system/ufw-blocklist-update.service /etc/systemd/system/ufw-blocklist-update.timer
sudo systemctl daemon-reload
sudo systemctl enable --now ufw-blocklist-update.timer
# Try once now:
sudo systemctl start ufw-blocklist-update.service