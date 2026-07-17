#!/usr/bin/env bash

# Raise a floating window after the pointer has rested over it briefly.
# Hyprland's follow_mouse setting performs the focus change; this listener
# only updates the floating z-order after a small debounce period.

set -u

HOVER_DELAY="${FLOAT_RAISE_DELAY:-0.12}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME_DIR/hypr-float-raise.lock"

command -v hyprctl >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1
command -v socat >/dev/null 2>&1 || exit 1
command -v flock >/dev/null 2>&1 || exit 1

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

socket_path() {
    printf '%s/hypr/%s/.socket2.sock\n' "$RUNTIME_DIR" "$HYPRLAND_INSTANCE_SIGNATURE"
}

raise_if_hovered() {
    local event_address="${1#0x}"
    local state address floating fullscreen

    [[ -n "$event_address" ]] || return 0
    sleep "$HOVER_DELAY"

    state="$(hyprctl activewindow -j 2>/dev/null)" || return 0
    IFS=$'\t' read -r address floating fullscreen < <(
        jq -r '[.address // "", .floating // false, .fullscreen // 0] | @tsv' <<<"$state"
    )

    [[ "${address#0x}" == "$event_address" ]] || return 0
    [[ "$floating" == "true" ]] || return 0
    [[ "$fullscreen" == "0" ]] || return 0

    hyprctl dispatch alterzorder "top,address:$address" >/dev/null 2>&1
}

while :; do
    SOCKET2="$(socket_path)"

    if [[ ! -S "$SOCKET2" ]]; then
        sleep 1
        continue
    fi

    while IFS= read -r event; do
        case "$event" in
            activewindowv2\>\>*)
                raise_if_hovered "${event#*>>}"
                ;;
        esac
    done < <(socat -u UNIX-CONNECT:"$SOCKET2" - 2>/dev/null)

    sleep 1
done
