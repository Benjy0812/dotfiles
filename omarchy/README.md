# Omarchy

Personal Omarchy (Hyprland + Quickshell) changes. Only files I changed are
tracked; everything else stays Omarchy's stock config.

| Path | Lives at | What |
|---|---|---|
| `hypr/custom.lua` | loaded from here | All personal Hyprland settings (see setup below) |
| `plugins/benjy.monitor-workspaces/` | `~/.config/omarchy/plugins/` | Workspaces 1-10 on every monitor, with bar widget. Install with its `setup.bash` |
| `shell/shell.json` | `~/.config/omarchy/shell.json` | Bar layout and idle settings |
| `apps/` | `~/.config/<app>/` | alacritty, git, mise, fcitx5, tensaku |

## `hypr/custom.lua`

- Apps menu moved from `SUPER+ALT+SPACE` to `SUPER+D`
- Norwegian keyboard layout, flat mouse acceleration
- Both AOC monitors (matched by description, so ports can change)
- No window rounding, dim inactive windows, full opacity

### Setup

`custom.lua` is loaded from `~/.config/hypr/hyprland.lua`, which needs two edits:

1. Before `require("default.hypr.omarchy")`, uncomment:

   ```lua
   omarchy_preinstalled_bindings = false
   ```

2. At the end, add:

   ```lua
   dofile(os.getenv("HOME") .. "/Projects/dotfiles/omarchy/hypr/custom.lua")
   ```

Then check with `hyprctl reload && hyprctl configerrors`. Redo both edits after
`omarchy refresh hyprland`, which resets `hyprland.lua`.

## Not included on purpose

Omarchy's default `~/.config/hypr` files, `gh/` (auth token), `*.bak*`
backups, browser and app state.
