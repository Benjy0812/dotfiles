-- Settings for benjy.monitor-workspaces, linked to ~/.config/hypr/monitor-workspaces.lua by
-- omarchy/install.bash. Apply changes with: hyprctl reload
return {
  -- Monitor order decides which block of workspace ids each one owns: the
  -- first gets 1-10, the second 11-20, and so on. Entries are a connector
  -- name ("DP-3") or a monitor description ("AOC C27G4ZXU 1O0Q7JA008205",
  -- see `hyprctl monitors`); the description survives cable and port swaps.
  -- Monitors not listed get the next free block in connection order.
  monitors = { "AOC C27G4ZXU 1O0Q7JA008205", "AOC 2590G4 0x000210C1" },
  -- Workspaces per monitor.
  per_monitor = 10,
}
