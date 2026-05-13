#!/bin/bash

if [ "$VERBOSE" = "true" ]; then
    sudo -E -u builduser PKGDEST=/home/builduser/packages makepkg --noconfirm -s --skipinteg -c
else
    if ! sudo -E -u builduser PKGDEST=/home/builduser/packages makepkg --noconfirm -s --skipinteg -c > /tmp/makepkg.log 2>&1; then
        echo "::error title=AUR Build Failed::Makepkg encountered an error while building a package!"
        echo -e "\n================ MAKEPKG LOG ================"
        cat /tmp/makepkg.log
        echo -e "=============================================\n"
        exit 1
    fi
fi