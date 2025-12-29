#!/bin/bash
# Update the package lists
pacman -Qqen > ~/dotfiles/pkg-lists/pacman_list.txt
pacman -Qqem > ~/dotfiles/pkg-lists/aur_list.txt

# Sync to GitHub
git add .
git commit -m "update: $(date +'%Y-%m-%d %H:%M')"
git push
