
if [[ -f /etc/ufw/blocklist.txt ]]; then
    sudo mv /etc/ufw/blocklist.txt /etc/ufw/blocklist.txt.bak
    echo "Backup of existing blocklist.txt stored to /etc/ufw/blocklist.txt.bak"
fi
if [[ -f /etc/ufw/blocklist-allow.txt ]]; then
    sudo mv /etc/ufw/blocklist-allow.txt /etc/ufw/blocklist-allow.txt.bak
    echo "Backup of existing blocklist-allow.txt stored to /etc/ufw/blocklist-allow.txt.bak"
fi
sudo cp blocklist-allow.txt /etc/ufw/blocklist-allow.txt
sudo chown root:root /etc/ufw/blocklist-allow.txt

sudo cp update-blocklist-sources.sh /usr/local/sbin/update-blocklist-sources.sh
sudo chown root:root /usr/local/sbin/update-blocklist-sources.sh
sudo chmod +x /usr/local/sbin/update-blocklist-sources.sh

sudo mv /etc/ufw/after.init /etc/ufw/after.init.bak
echo "Backup of original after.init at /etc/ufw/after.init.bak"
sudo cp after.init /etc/ufw/
sudo chown root:root /etc/ufw/after.init
sudo chmod +x /etc/ufw/after.init

sudo USE_UFW_RELOAD=true /usr/local/sbin/update-blocklist-sources.sh
sudo ufw status verbose

# Inspect placement:
sudo iptables -L ufw-before-input --line-numbers -v
sudo iptables -L ufw-before-output --line-numbers -v
sudo iptables -S BLOCKLIST
sudo ipset list blocklist | head
