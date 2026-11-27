# benjy.workspaces

Workspace groups for [Omarchy](https://omarchy.org): each monitor gets 3 groups
of 10 workspaces. Group 1 is Omarchy's own per-monitor 1-10; groups 2 and 3 are
named workspaces tied to the physical monitor.

- `SUPER+1`-`0` (and the `SHIFT` / `SHIFT+ALT` moves) act on the focused
  monitor's current group.
- `SUPER+Page Down` / `Page Up` switch group, keeping the slot; with `SHIFT`
  (`+ALT`) the window moves to the same slot in that group.
- `Workspaces.qml` is the bar widget (clone of `omarchy.workspaces`) that shows
  `G1`-`G3`.

| File                  | What                                                                |
| --------------------- | ------------------------------------------------------------------- |
| `workspaces.lua`      | Hyprland side: binds and group logic, loaded from `hypr/custom.lua` |
| `Workspaces.qml`      | Bar widget                                                          |
| `test_workspaces.lua` | `lua test_workspaces.lua` checks the workspace-name parser          |

A config reload or monitor change snaps each monitor back to group 1; windows
in groups 2 and 3 stay where they are.
