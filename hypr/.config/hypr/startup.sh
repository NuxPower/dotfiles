#!/bin/bash

# Function to launch apps on specific workspaces
# Usage: launch_on_workspace <workspace_id> <command>
launch_on_workspace() {
    hyprctl dispatch exec "[workspace $1] $2"
}

# 1. System Monitor (Workspace 1)
# We use the title rule here to ensure it tiles where you want
launch_on_workspace 1 "kitty --title system_monitor -o font_size=9 -e btop"
sleep 0.5

# 2. Main Shell (Workspace 1)
launch_on_workspace 1 "kitty --title shell"
sleep 0.5

# 3. Falkon (Workspace 2)
launch_on_workspace 2 "falkon"

# 4. Ferdium (Workspace 3)
# Using the ozone flags you mentioned for Wayland stability
launch_on_workspace 3 "ferdium --enable-features=UseOzonePlatform --ozone-platform=wayland"

# 5. Spotify (Workspace 4)
# Putting the sleep here inside the script instead of the config
sleep 5
launch_on_workspace 4 "flatpak run com.spotify.Client --enable-features=UseOzonePlatform --ozone-platform=wayland"
