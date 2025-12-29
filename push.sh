#!/bin/bash
# 1. Update package lists
pacman -Qqen > ~/dotfiles/pkg-lists/pacman_list.txt
pacman -Qqem > ~/dotfiles/pkg-lists/aur_list.txt

# 2. Push to GitHub
cd ~/dotfiles
git add .
git commit -m "Auto-update: $(date +'%Y-%m-%d %H:%M')"
git push origin main
