#!/bin/bash
set -euo pipefail

CPU_ARCH="$1"

if [ -z "$CPU_ARCH" ]; then
    echo "CPU architecture not provided. Defaulting to v3."
    CPU_ARCH="v3"
fi

echo "Setting CPU architecture to $CPU_ARCH"

REPO_FILE=$(mktemp)

case "$CPU_ARCH" in
    "znver4")
        cat > "$REPO_FILE" <<EOF
[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

EOF
        ;;
    "v4")
        cat > "$REPO_FILE" <<EOF

[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
EOF
        ;;
    *) # Default to v3
        # v3 is the default configuration, no extra repos needed.
        ;;
esac

# Insert the repo config before the [cachyos] section so it takes precedence
awk -v repo_file="$REPO_FILE" '/^#?\[cachyos\]/ && !done { system("cat " repo_file); done=1 } { print }' /etc/pacman.conf > /etc/pacman.conf.tmp && mv /etc/pacman.conf.tmp /etc/pacman.conf

rm -f "$REPO_FILE"

cat /etc/pacman.conf

# Synchronize databases
echo "Synchronizing package databases..."
pacman -Syy

# Reinstall all base packages from the newly enabled repos to get optimized versions
echo "Reinstalling all packages to apply CPU optimizations..."
pacman -Qqn | pacman -S --noconfirm - && pacman -Scc --noconfirm

echo "CPU optimization step complete."
