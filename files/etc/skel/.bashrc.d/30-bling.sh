# Interactive Shell Bling (Atuin, Starship, Zoxide)

# bash-preexec is required for tools like atuin to correctly hook the shell
if [[ -f /usr/share/bash-preexec/bash-preexec.sh ]]; then
   source /usr/share/bash-preexec/bash-preexec.sh
fi

if command -v atuin > /dev/null; then
    eval "$(atuin init bash)"
fi

if command -v starship > /dev/null; then
    eval "$(starship init bash)"
fi

if command -v zoxide > /dev/null; then
    eval "$(zoxide init bash)"
fi

# Custom Keybindings: PageUp/PageDown history search
bind '"\e[5~": history-search-backward'
bind '"\e[6~": history-search-forward'