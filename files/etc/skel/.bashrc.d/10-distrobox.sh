# Distrobox / Container interactive shell tweaks
if [ -n "${CONTAINER_ID}" ] || [ -n "${DISTROBOX_ENTER_PATH}" ]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    # Force Job Control on for Arch/Cachy containers (Fixes Ctrl+C issues)
    if [[ "$ID" == "cachyos" || "$ID" == "arch" ]]; then
        set -m
    fi

    if ! command -v xdg-open > /dev/null; then
        alias xdg-open='distrobox-host-exec'
    fi
    alias mullvad-exclude='distrobox-host-exec mullvad-exclude'
fi