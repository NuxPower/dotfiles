#!/bin/bash

# btop (stack top)
kitty --title system_monitor -o font_size=9 -e btop &
sleep 0.6

# zsh (MASTER)
kitty --title shell &

