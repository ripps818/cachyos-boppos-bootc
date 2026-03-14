#!/bin/bash
set -euo pipefail

# This script is called by the Justfile to handle image signing.
# It's moved to a separate script to avoid complex shell escaping issues within the Justfile.

# --- Arguments from Justfile ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <full_image_name> <architecture>" >&2
    exit 1
fi
FULL_IMAGE="$1"
ARCH="$2"

# --- Logic ---
echo "Signing ${FULL_IMAGE}:${ARCH}..."

# Determine the signing key argument
if [ -n "${COSIGN_PRIVATE_KEY-}" ]; then
    KEY_ARG="--key env://COSIGN_PRIVATE_KEY"
    echo "Using COSIGN_PRIVATE_KEY from environment."
elif [ -f "cosign.key" ]; then
    KEY_ARG="--key cosign.key"
    echo "Using local cosign.key file."
else
    echo "Error: COSIGN_PRIVATE_KEY environment variable is not set and cosign.key is missing." >&2
    exit 1
fi

# Check for the digest file and read the digest
DIGEST_FILE="/tmp/podman_push_digest_${ARCH}.txt"
if ! [ -s "$DIGEST_FILE" ]; then
    echo "Error: Digest file \"$DIGEST_FILE\" not found or is empty. Did the 'push' recipe run successfully?" >&2
    exit 1
fi
DIGEST=$(head -n 1 "$DIGEST_FILE" | tr -d '[:space:]')
if [ -z "$DIGEST" ]; then
    echo "Error: Digest read from \"$DIGEST_FILE\" is empty. File content: \`cat \"$DIGEST_FILE\"\`" >&2
    exit 1
fi

echo "Signing image with digest: $DIGEST"

# Execute the cosign command with sudo to handle registry authentication.
# `sudo` allows cosign to use the root-owned credentials in /etc/containers/auth.json.
# `sudo -E` is used to preserve the COSIGN_PRIVATE_KEY environment variable if it is set.
# We also explicitly set REGISTRY_AUTH_FILE to ensure cosign finds the correct credentials,
# mirroring the --authfile flag used in the Justfile's push recipe.
sudo -E REGISTRY_AUTH_FILE=/etc/containers/auth.json cosign sign -y --new-bundle-format=false --use-signing-config=false $KEY_ARG "${FULL_IMAGE}@${DIGEST}"