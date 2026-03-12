# The registry to push the image to.
# Change this to your preferred registry (e.g., ghcr.io, docker.io).
REGISTRY := "quay.io"

# Your username or organization on the registry.
# !!! IMPORTANT: CHANGE THIS to your actual username !!!
USER := "user"

# The name of the image.
IMAGE := "boppos-cachyos"

# The default tag for the image, usually points to the most compatible build.
TAG := "latest"

# The full image name with registry and user.
FULL_IMAGE_NAME := "{{REGISTRY}}/{{USER}}/{{IMAGE}}"

# --- Recipes ---

# The default recipe, runs when you just type 'just'.
default: build

# Build the container image.
# Accepts an optional architecture (v3, v4, znver4).
# Usage:
#   just build         (builds for v3 and tags as 'latest')
#   just build v4      (builds for v4)
#   just build znver4  (builds for znver4)
build arch='v3':
    #!/usr/bin/env bash
    set -euxo pipefail
    echo "Building {{FULL_IMAGE_NAME}}:{{arch}} for TARGET_CPU_MARCH={{arch}}..."
    podman build \
        --build-arg TARGET_CPU_MARCH={{arch}} \
        -t "{{FULL_IMAGE_NAME}}:{{arch}}" \
        .
    # Also tag the v3 build as 'latest' for convenience
    if [[ "{{arch}}" == "v3" ]]; then
        podman tag "{{FULL_IMAGE_NAME}}:{{arch}}" "{{FULL_IMAGE_NAME}}:{{TAG}}"
        echo "Tagged {{FULL_IMAGE_NAME}}:{{arch}} as {{FULL_IMAGE_NAME}}:{{TAG}}"
    fi

# Push the built image(s) to the container registry.
# Pushes both the arch-specific tag and the 'latest' tag if it exists.
# Usage:
#   just push         (pushes the v3 and 'latest' tags)
#   just push v4      (pushes the v4 tag)
#   just push znver4  (pushes the znver4 tag)
push arch='v3':
    #!/usr/bin/env bash
    set -euxo pipefail
    echo "Pushing {{FULL_IMAGE_NAME}}:{{arch}}..."
    podman push "{{FULL_IMAGE_NAME}}:{{arch}}"
    # Also push the 'latest' tag if it's the v3 build
    if [[ "{{arch}}" == "v3" ]]; then
        if podman image exists "{{FULL_IMAGE_NAME}}:{{TAG}}"; then
            echo "Pushing {{FULL_IMAGE_NAME}}:{{TAG}}..."
            podman push "{{FULL_IMAGE_NAME}}:{{TAG}}"
        fi
    fi

# Display the command to switch to this image on a bootc-enabled system.
# Usage:
#   just switch         (shows command for the 'latest' tag)
#   just switch v4      (shows command for the v4 tag)
#   just switch znver4  (shows command for the znver4 tag)
switch arch='latest':
    #!/usr/bin/env bash
    echo
    echo "------------------------------------------------------------------"
    echo "  On your target machine, run the following command to switch:"
    echo "------------------------------------------------------------------"
    echo
    echo "    sudo bootc switch {{FULL_IMAGE_NAME}}:{{arch}}"
    echo
    echo "------------------------------------------------------------------"
    echo
