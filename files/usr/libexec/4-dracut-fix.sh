#!/bin/bash
set -euo pipefail

# This script ensures dracut builds the initramfs for the installed kernel,
# not the kernel of the container runner.

# Get the version of the newly installed kernel
KERNEL_VERSION=$(ls /usr/lib/modules | grep -E 'cachyos' | head -n 1)

if [ -z "$KERNEL_VERSION" ]; then
    echo "Error: CachyOS kernel not found."
    exit 1
fi

echo "Forcing dracut for kernel: $KERNEL_VERSION"

# Force dracut to build the initramfs for the correct kernel
# - Hostonfly=no: important for portable images
# - add ostree bootc: required modules for bootc
dracut --force --no-hostonly --add "ostree bootc" --kver "$KERNEL_VERSION"
