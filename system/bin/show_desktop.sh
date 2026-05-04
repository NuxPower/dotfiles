#!/bin/bash

# Get the name of the current workspace
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.name')

if [ "$CURRENT_WS" = "99" ]; then
    # We are currently looking at the empty desktop
    # Read where we came from and jump back
    if [ -f /tmp/prev_workspace ]; then
        PREV_WS=$(cat /tmp/prev_workspace)
        hyprctl dispatch workspace "$PREV_WS"
    fi
else
    # We are on an active workspace
    # Save this location and jump to workspace 99
    echo "$CURRENT_WS" > /tmp/prev_workspace
    hyprctl dispatch workspace 99
fi
