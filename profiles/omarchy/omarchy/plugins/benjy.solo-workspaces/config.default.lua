-- Settings for benjy.solo-workspaces. Copy to ~/.config/hypr/solo-workspaces.lua
-- (dotfiles.bash setup links profiles/omarchy/hypr/solo-workspaces.lua there
-- instead). Changes apply on their own a moment after saving.
return {
  -- Window classes (see `hyprctl clients`), matched without case.
  -- An entry starting with "^" is a Lua pattern, e.g. "^steam_app_%d+$".
  apps = { "org.jellyfin.JellyfinDesktop" },
  -- When another window lands on a solo app's workspace:
  -- true = that window moves away, false = it stays and shares.
  push_others = true,
  -- Go along to the workspace a moved window lands on.
  follow = true,
  -- Workspaces 1..slots are searched for a free one.
  slots = 10,
}
