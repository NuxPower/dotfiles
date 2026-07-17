#!/usr/bin/env bash
set -euo pipefail

# SPDX-FileCopyrightText: 2025-present Ahum Maitra theahummaitra@gmail.com
#
# SPDX-License-Identifier: 	GPL-3.0-or-later

# Repository url : https://github.com/TheAhumMaitra/cautious-waddle

require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s\n' "Missing dependency: $1" >&2
    exit 127
  }
}

require wallust
require rofi

# notify-send is optional
have_notify() { command -v notify-send >/dev/null 2>&1; }

# Wallust prints palette previews as ANSI true-color blocks. Convert those
# blocks into small SVG icons that rofi can show beside each theme name.
theme_preview_cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/theme-previews"
wallust_cache_version="$(wallust --version | sha256sum | cut -d' ' -f1)"
theme_preview_cache="$theme_preview_cache/$wallust_cache_version"
mkdir -p "$theme_preview_cache"

mapfile -t themes < <(
  wallust theme list \
    | sed -n 's/^- //p' \
    | sed -e '/^random (select a random theme)$/d' \
          -e '/^list (lists available themes) *$/d'
)

theme_icon_path() {
  local theme=${1//\//_}
  printf '%s/%s.svg' "$theme_preview_cache" "$theme"
}

generate_theme_icon() {
  local theme=$1 icon=$2 preview match color
  local rgb_re=$'\e''\[48;2;([0-9]+);([0-9]+);([0-9]+)m'
  local -a colors=()

  preview="$(wallust theme --preview --skip-sequences --skip-templates -- "$theme" 2>/dev/null)" || return 1

  while [[ $preview =~ $rgb_re ]]; do
    match=${BASH_REMATCH[0]}
    printf -v color '#%02X%02X%02X' \
      "$((10#${BASH_REMATCH[1]}))" \
      "$((10#${BASH_REMATCH[2]}))" \
      "$((10#${BASH_REMATCH[3]}))"
    colors+=("$color")
    preview=${preview#*"$match"}
  done

  (( ${#colors[@]} == 16 )) || return 1

  local tmp_icon="$icon.tmp.$$" index x y
  {
    printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
    printf '%s\n' '  <defs><clipPath id="palette"><rect width="64" height="64" rx="8"/></clipPath></defs>'
    printf '%s\n' '  <g clip-path="url(#palette)">'
    for index in "${!colors[@]}"; do
      x=$((index % 4 * 16))
      y=$((index / 4 * 16))
      printf '    <rect x="%d" y="%d" width="16" height="16" fill="%s"/>\n' \
        "$x" "$y" "${colors[$index]}"
    done
    printf '%s\n' '  </g>'
    printf '%s\n' '  <rect x="0.5" y="0.5" width="63" height="63" rx="7.5" fill="none" stroke="#fff" stroke-opacity="0.28"/>'
    printf '%s\n' '</svg>'
  } > "$tmp_icon"
  mv "$tmp_icon" "$icon"
}

# Serialize first-run cache generation in case the shortcut is pressed twice.
exec {preview_lock_fd}>"$theme_preview_cache/.lock"
flock "$preview_lock_fd"
if [[ ! -f "$theme_preview_cache/.complete" ]]; then
  have_notify && notify-send -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Preparing theme previews" "This only happens once per Wallust version." || true

  previews_complete=true
  for theme in "${themes[@]}"; do
    icon="$(theme_icon_path "$theme")"
    if [[ ! -s "$icon" ]] && ! generate_theme_icon "$theme" "$icon"; then
      previews_complete=false
    fi
  done
  "$previews_complete" && touch "$theme_preview_cache/.complete"
fi
flock -u "$preview_lock_fd"

build_rofi_rows() {
  local theme icon
  for theme in "${themes[@]}"; do
    icon="$(theme_icon_path "$theme")"
    if [[ -s "$icon" ]]; then
      printf '%s\0icon\x1f%s\n' "$theme" "$icon"
    else
      printf '%s\n' "$theme"
    fi
  done
}

# Prompt for theme; guard -e on cancel. The original row value remains the
# plain Wallust theme name even though rofi also receives an icon per row.
set +e
choice="$(build_rofi_rows \
  | rofi -dmenu -i -no-custom -show-icons \
      -p 'Select Global Theme' \
      -mesg '16-color palette preview · Enter to apply' \
      -theme-str 'element-icon { size: 42px; }')"
prompt_status=$?
set -e

# Exit cleanly on cancel or empty selection
if (( prompt_status != 0 )) || [[ -z "${choice}" ]]; then
  exit 0
fi

# Record time before applying so we can wait for fresh template outputs
start_ts=$(date +%s)

# Apply the theme and report result
if wallust theme -- "${choice}"; then
  have_notify && notify-send -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Global theme changed" "Selected: ${choice}"

  # Wait until template targets exist, are newer than start_ts, and are stable (size/mtime stops changing)
  # Ensure Ghostty directory exists so Wallust can write target even if Ghostty isn't installed
  mkdir -p "$HOME/.config/ghostty" || true

  targets=(
    "$HOME/.config/waybar/wallust/colors-waybar.css"
    "$HOME/.config/rofi/wallust/colors-rofi.rasi"
    "$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
    "$HOME/.config/hypr/wallust/wallust-hyprland.conf"
    "$HOME/.config/ghostty/wallust.conf"
  )

  # Normalize Ghostty palette syntax in case upstream templates or older targets used ':'
  ghostty_conf="$HOME/.config/ghostty/wallust.conf"
  if [ -f "$ghostty_conf" ]; then
    sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$ghostty_conf" 2>/dev/null || true
  fi

  # Phase 1: appearance + freshness
  for _ in $(seq 1 100); do # up to ~10s
    ok=1
    for f in "${targets[@]}"; do
      [ -s "$f" ] || { ok=0; break; }
      mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
      [ "$mtime" -ge "$start_ts" ] || { ok=0; break; }
    done
    [ $ok -eq 1 ] && break
    sleep 0.1
  done

  # Phase 2: stability (avoid reading half-written files)
  if [ $ok -eq 1 ]; then
    for _ in 1 2 3; do
      sizes_a=(); mtimes_a=()
      for f in "${targets[@]}"; do
        sizes_a+=("$(stat -c %s "$f" 2>/dev/null || echo 0)")
        mtimes_a+=("$(stat -c %Y "$f" 2>/dev/null || echo 0)")
      done
      sleep 0.15
      sizes_b=(); mtimes_b=()
      for f in "${targets[@]}"; do
        sizes_b+=("$(stat -c %s "$f" 2>/dev/null || echo 0)")
        mtimes_b+=("$(stat -c %Y "$f" 2>/dev/null || echo 0)")
      done
      if [ "${sizes_a[*]}" = "${sizes_b[*]}" ] && [ "${mtimes_a[*]}" = "${mtimes_b[*]}" ]; then
        break
      fi
    done
  else
    # As a safety net, wait a bit to avoid racing rofi reload against template writes
    sleep 0.5
  fi

  # Small cushion before refresh to mirror wallpaper flow
  sleep 0.2
  # Normalize Rofi selection colors to use the palette's accent (color12)
  rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"
  if [ -f "$rofi_colors" ]; then
    accent_hex=$(sed -n 's/^\s*color12:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
    [ -z "$accent_hex" ] && accent_hex=$(sed -n 's/^\s*color13:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
    if [ -n "$accent_hex" ]; then
      sed -i -E "s|^(\s*selected-normal-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-active-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-urgent-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-normal-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-active-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-urgent-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
    fi
  fi

  # Reload Hyprland so new border colors from wallust-hyprland.conf take effect
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  # Refresh bars/menus after files are ready
  if [ -x "$HOME/.config/hypr/scripts/Refresh.sh" ]; then
    "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 || true
  else
    if command -v waybar-msg >/dev/null 2>&1; then
      waybar-msg cmd reload >/dev/null 2>&1 || true
    else
      pkill -SIGUSR2 waybar >/dev/null 2>&1 || true
    fi
  fi

  # Ask kitty to reload its config so the new 01-Wallust.conf is picked up
  if pidof kitty >/dev/null; then
    for pid in $(pidof kitty); do kill -SIGUSR1 "$pid" 2>/dev/null || true; done
  fi

  # Ask ghostty to reload its config so the updated wallust.conf is applied
  if pidof ghostty >/dev/null; then
    for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
  fi
else
  have_notify && notify-send -u critical -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Failed to apply theme" "${choice}"
  exit 1
fi
