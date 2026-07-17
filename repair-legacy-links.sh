#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# link path (under $HOME)|target path (under the repository)
links=(
    '.config/rices/personal/btop|btop/.config/btop'
    '.config/rices/personal/fastfetch|fastfetch/.config/fastfetch'
    '.config/rices/personal/hypr/hyprland.conf|hypr/.config/hypr/hyprland.conf'
    '.config/rices/personal/hypr/startup.sh|hypr/.config/hypr/startup.sh'
    '.config/rices/personal/kitty/kitty.conf|kitty/.config/kitty/kitty.conf'
    '.config/rices/personal/waybar/config|waybar/.config/waybar/config'
    '.config/rices/personal/waybar/style.css|waybar/.config/waybar/style.css'
)

for mapping in "${links[@]}"; do
    link_path="$HOME/${mapping%%|*}"
    target_path="$REPO_DIR/${mapping#*|}"

    [[ -e "$target_path" ]] || {
        printf 'Skipping missing target: %s\n' "$target_path" >&2
        continue
    }
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
        printf 'Refusing to replace a real file/directory: %s\n' "$link_path" >&2
        exit 1
    fi

    mkdir -p "$(dirname -- "$link_path")"
    ln -sfn -- "$target_path" "$link_path"
    printf 'Linked %s -> %s\n' "$link_path" "$target_path"
done
