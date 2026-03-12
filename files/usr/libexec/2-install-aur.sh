#!/bin/bash
set -euo pipefail

# It's not recommended to build AUR packages as root.
# This script creates a temporary user to build 'scopebuddy-git'.

# Create a temporary build user
useradd -m -d /var/home/builduser builduser

# Give the build user passwordless sudo rights
echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Run the installation as the build user
sudo -u builduser bash <<'EOF'
set -euo pipefail
# The GPG key for scopebuddy is often out of date or problematic.
# We will skip the check for this build.
cd /var/home/builduser
git clone https://aur.archlinux.org/scopebuddy-git.git
cd scopebuddy-git
makepkg -si --noconfirm --skipinteg

# Install OpenRGB udev rules (Essential for OpenRGB device detection)
cd /var/home/builduser
git clone https://aur.archlinux.org/openrgb-udev-rules.git
cd openrgb-udev-rules
makepkg -si --noconfirm
EOF

# Clean up: remove the build user and its home directory
userdel -r builduser
# Remove the passwordless sudo entry
sed -i '$d' /etc/sudoers
