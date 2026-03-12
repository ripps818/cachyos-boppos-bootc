#!/bin/bash
set -euo pipefail

# This script configures the global shell environment for all users.

BASHRC_FILE="/etc/bash.bashrc"

echo "Adding starship, zoxide, and eza alias to $BASHRC_FILE"

# Add configurations to the end of the file
cat >> "$BASHRC_FILE" <<'EOF'

# Added by BoppOS build process

# -----------------------------------------------------------------------------
# Starship - The cross-shell prompt
# -----------------------------------------------------------------------------
eval "$(starship init bash)"

# -----------------------------------------------------------------------------
# zoxide - A smarter cd command
# -----------------------------------------------------------------------------
eval "$(zoxide init bash)"

# -----------------------------------------------------------------------------
# eza - A modern replacement for 'ls'
# -----------------------------------------------------------------------------
alias ls='eza --icons'

EOF

echo "Shell configuration complete."
