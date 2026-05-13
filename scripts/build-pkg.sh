#!/bin/bash

# Ensure cache directories exist and are accessible by builduser
sudo mkdir -p /var/cache/makepkg/src /var/cache/makepkg/ccache
sudo chown -R builduser:builduser /var/cache/makepkg

export SRCDEST=/var/cache/makepkg/src
export CCACHE_DIR=/var/cache/makepkg/ccache
export CCACHE_MAXSIZE=2G

if [ "$VERBOSE" = "true" ]; then
    sudo -E -u builduser PKGDEST=/home/builduser/packages SRCDEST=$SRCDEST CCACHE_DIR=$CCACHE_DIR makepkg --noconfirm -s --skipinteg -c
else
    if ! sudo -E -u builduser PKGDEST=/home/builduser/packages SRCDEST=$SRCDEST CCACHE_DIR=$CCACHE_DIR makepkg --noconfirm -s --skipinteg -c > /tmp/makepkg.log 2>&1; then
        echo "::error title=AUR Build Failed::Makepkg encountered an error while building a package!"
        echo -e "\n================ MAKEPKG LOG ================"
        cat /tmp/makepkg.log
        echo -e "=============================================\n"
        exit 1
    fi
fi