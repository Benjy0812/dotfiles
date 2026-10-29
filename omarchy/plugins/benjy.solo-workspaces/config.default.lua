-- Settings for benjy.solo-workspaces. setup.bash created this file and never
-- overwrites it. Changes apply on their own a moment after saving.
return {
  -- Window classes (see `hyprctl clients`), matched without case.
  apps = { "vesktop" },
  -- Also move other windows off a solo app's workspace.
  push_others = true,
  -- Go along to the workspace a moved window lands on.
  follow = true,
  -- Workspaces 1..slots are searched for a free one.
  slots = 10,
}
