#!/bin/bash
# Update the package lists
pacman -Qqen > ~/dotfiles/pkg-lists/pacman_list.txt
pacman -Qqem > ~/dotfiles/pkg-lists/aur_list.txt

# Sync to GitHub
cd ~/dotfiles
git add .
if git commit -m "Auto-update: $(date +'%Y-%m-%d %H:%M')"; then
    git push origin main
    notify-send "Dotfiles Backup" "Successfully pushed to GitHub!" --icon=org.kde.plasma.emojier
else
    notify-send "Dotfiles Backup" "No changes to push." --icon=dialog-information
fi
