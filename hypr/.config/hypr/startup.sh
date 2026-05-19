#!/bin/bash
sleep 5
# Function to launch apps on specific workspaces
# Usage: launch_on_workspace <workspace_id> <command>
launch_on_workspace() {
    hyprctl dispatch exec "[workspace $1 silent] $2"
}

# --- WORKSPACE 1: 2x2 CUSTOM DASHBOARD ---
# 1. Top Left (Initial Window)
launch_on_workspace 1 "kitty --title music -e cava"
sleep 0.8
# 2. Split Right -> Top Right
launch_on_workspace 1 "kitty --title system_monitor -e btop"
sleep 0.5

# 3. Focus Top Left and Split Down -> Bottom Left
hyprctl dispatch focuswindow title:system_monitor
launch_on_workspace 1 "kitty --title clock -e tty-clock -c -C 5 -r -s -t"
sleep 0.5

# 4. Focus Top Right and Split Down -> Bottom Right (The "Junk" Tile)
hyprctl dispatch focuswindow title:music
launch_on_workspace 1 "kitty --title shell"
sleep 0.5
# Focus the clock (bottom window)
hyprctl dispatch focuswindow title:system_monitor

# Resize the clock to be SHORTER (which makes btop TALLER)
# We move the split line down by 100 pixels
hyprctl dispatch resizeactive 0 150 

hyprctl dispatch focuswindow title:music
hyprctl dispatch resizeactive 0 -150
launch_on_workspace 6 "kitty --title Neovim -e nvim"
sleep 0.5
# 3. Falkon (Workspace 2)
launch_on_workspace 2 "zen-browser"

# 4. Ferdium (Workspace 3)
# Using the ozone flags you mentioned for Wayland stability
#launch_on_workspace 3 "ferdium --enable-features=UseOzonePlatform --ozone-platform=wayland"

# 5. Spotify (Workspace 4)
# Putting the sleep here inside the script instead of the config
sleep 5
launch_on_workspace 4 "spotify --enable-features=UseOzonePlatform --ozone-platform=wayland"

sleep 2
launch_on_workspace 5 "discord --enable-features=UseOzonePlatform --ozone-platform=wayland"


# Focus the 4th tile (Bottom Right)
# hyprctl dispatch focuswindow title:shell

# Any new window sent here will now become a "Tab" in this corner
# windowrule = match:workspace 1, group set
