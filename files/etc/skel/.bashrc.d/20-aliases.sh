# Aliases & Keybindings
if command -v eza > /dev/null; then
    alias ls='eza --icons=auto'
    alias ll='eza -l --icons=auto --group-directories-first'
    alias la='eza -la --icons=auto --group-directories-first'
    alias l.='eza -d .*'
fi