#!/bin/bash

# System cleanup and advanced refresh script

# Clear system caches
echo "Clearing system caches..."
sudo sync
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
sudo rm -rf /var/cache/*

# Clear temporary files and directories
echo "Clearing temporary files..."
rm -rf "$HOME/.cache/"*
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear package manager caches
echo "Clearing package manager caches..."
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y

# Remove unused kernel versions
echo "Removing unused kernel versions..."
sudo apt-get purge $(dpkg -l 'linux-*' | awk '/^ii/{ print $2}' | grep -E 'linux-(image|headers|modules|tools)-[0-9]' | grep -v $(uname -r))

# Reset machine ID
echo "Updating machine ID..."
sudo rm /etc/machine-id
sudo dbus-uuidgen --ensure=/etc/machine-id

# Update hostname
new_hostname="linux-$(openssl rand -hex 4)"
echo "Setting new hostname to: $new_hostname"
sudo hostnamectl set-hostname "$new_hostname"

# Clear bash history
echo "Clearing bash history..."
history -c
rm "$HOME/.bash_history"

# Clear system logs
echo "Clearing system logs..."
sudo find /var/log -type f -exec truncate -s 0 {} \;

# Reset network settings
echo "Resetting network settings..."
sudo service NetworkManager restart

# Update and upgrade system packages
echo "Updating and upgrading system packages..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

# Perform system health checks (optional)
echo "Performing system health checks..."
sudo apt-get check
sudo fsck -y

echo "System refresh complete!"
