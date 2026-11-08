-- Settings for benjy.solo-workspaces, linked to ~/.config/hypr/solo-workspaces.lua by
-- dotfiles.bash setup. Changes apply on their own a moment after saving.
return {
  -- Window classes (see `hyprctl clients`), matched without case.
  -- An entry starting with "^" is a Lua pattern; "^steam_app_%d+$" = every Steam game.
  apps = { "org.jellyfin.JellyfinDesktop", "chrome-discord.com__channels_@me-Default", "^steam_app_%d+$" },
  -- When another window lands on a solo app's workspace:
  -- true = that window moves away, false = it stays and shares.
  push_others = true,
  -- Go along to the workspace a moved window lands on.
  follow = true,
  -- Workspaces 1..slots are searched for a free one.
  slots = 10,
}
