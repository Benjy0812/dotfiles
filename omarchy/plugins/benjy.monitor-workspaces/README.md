# Monitor Workspaces

Independent workspaces on every monitor for [Omarchy](https://omarchy.org),
the way mangowm, dwm and awesome do it: each screen has its own 1-10, and
`SUPER+3` goes to workspace 3 of the screen you're on.

Two parts, no compositor plugin needed:

- **`monitor-workspaces.lua`** - Hyprland side, using the Lua config API
  (Hyprland 0.55+). Each monitor owns a block of real workspace ids (first
  monitor 1-10, second 11-20, ...), pinned to it with workspace rules.
- **`Widget.qml`** - Omarchy bar widget. Each bar shows only its own
  monitor's workspaces, numbered 1-10. It reads the blocks from Hyprland's
  workspace rules, so there is nothing to configure in it.

## Keys

| Keys | Action |
| --- | --- |
| `SUPER+1..0` | Go to workspace N on the focused monitor |
| `SUPER+SHIFT+1..0` | Move window to workspace N and follow |
| `SUPER+SHIFT+ALT+1..0` | Move window to workspace N silently |
| `SUPER+TAB` / `SUPER+SHIFT+TAB` / `SUPER+scroll` | Cycle this monitor's open workspaces |

These replace Omarchy's global workspace binds. Everything else is untouched.

## Bar widget

- The highlighted dot marks the workspace shown on that monitor; it's dimmer
  when another monitor has focus.
- Slots 1-5 are always shown, 6-10 appear when in use. Change that with the
  `minimumSlots` setting on the widget's entry in `~/.config/omarchy/shell.json`.
- Clicking an empty slot creates it on that bar's monitor.

## Configure

Set the monitor order at the top of `monitor-workspaces.lua`:

```lua
M.monitors = { "DP-3", "DP-2" }  -- DP-3 gets 1-10, DP-2 gets 11-20
```

Names come from `hyprctl monitors`. An unlisted monitor gets the next block.

## Install

```sh
./setup.bash            # install, hook into hypr/bindings.lua, swap the bar widget
./setup.bash uninstall  # undo all three
```

Run `setup.bash` again after editing files here, and after
`omarchy refresh hyprland` or `omarchy refresh shell`, which reset the hook
and the bar.

## Why not hyprsplit?

[hyprsplit](https://github.com/shezdy/hyprsplit) and split-monitor-workspaces
are C++ plugins written for the legacy config, and hyprsplit refuses to load
under the Lua config Omarchy uses.

## License

MIT. `Widget.qml` is derived from Omarchy's `omarchy.workspaces` widget; see
[LICENSE](LICENSE).
