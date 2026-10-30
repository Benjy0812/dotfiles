-- Settings for benjy.monitor-workspaces. dotfiles.bash setup created this file and
-- never overwrites it. Apply changes with: hyprctl reload
return {
  -- Monitor order decides which block of workspace ids each one owns: the
  -- first gets 1-10, the second 11-20, and so on. Entries are a connector
  -- name ("DP-3") or a monitor description ("AOC C27G4ZXU 1O0Q7JA008205",
  -- see `hyprctl monitors`); the description survives cable and port swaps.
  -- Monitors not listed get the next free block in connection order.
  monitors = {},
  -- Workspaces per monitor.
  per_monitor = 10,
}
