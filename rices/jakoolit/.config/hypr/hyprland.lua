-- Keep upstream desktop updates and personal input settings separate.
dofile(os.getenv("HOME") .. "/43pr-dotfiles/.config/hypr/hyprland.lua")
require("local-input")
require("local-monitors")
require("local-workspaces")
