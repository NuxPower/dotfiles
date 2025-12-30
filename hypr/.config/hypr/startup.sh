#!/bin/bash

# btop (stack top)
kitty --title system_monitor -o font_size=9 -e btop &
sleep 0.6

# zsh (MASTER)
kitty --title shell &

#sleep 15
#flatpak run com.spotify.Client --enable-features=UseOzonePlatform --ozone-platform=wayland &
