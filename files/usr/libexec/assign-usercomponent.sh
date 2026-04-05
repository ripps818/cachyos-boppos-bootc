#!/bin/bash

while read -r pkgname; do
    # Query the package files, catching the exit code if pacman fails
    if ! file_list=$(pacman -Qlq "$pkgname" 2>/dev/null); then
        echo "Warning: Failed to query files for package '$pkgname'" >&2
        continue
    fi

    # Iterate over the captured file list
    while read -r filepath; do
        # Only target regular files (ignore symlinks and directories)
        if [[ -f "$filepath" && ! -L "$filepath" ]]; then
            setfattr -n user.component -v "$pkgname" "$filepath"
        fi
    done <<< "$file_list"
done
