# Omarchy

Personal Omarchy (Hyprland + Quickshell) changes. Only files I changed are
tracked; everything else stays Omarchy's stock config.

| Path | Lives at | What |
|---|---|---|
| `hypr/custom.lua` | loaded from here (also linked) | All personal Hyprland settings (see setup below) |
| `hypr/solo-workspaces.lua` | linked to `~/.config/hypr/` | My settings for the solo-workspaces plugin: the solo apps (Jellyfin) |
| [`omarchy/plugins/benjy.solo-workspaces/`](omarchy/plugins/benjy.solo-workspaces/README.md) | `~/.config/omarchy/plugins/` | Listed apps get a workspace to themselves, moved to the nearest empty one |
| `omarchy/plugins/benjy.workspaces/` | `~/.config/omarchy/plugins/` | Workspace groups: 3 groups of 10 per monitor (`SUPER+PgDn/PgUp`), and a bar widget (clone of `omarchy.workspaces`) showing `G1`-`G3` |
| `omarchy/shell.json` | `~/.config/omarchy/shell.json` | Bar layout and idle settings |

## `hypr/custom.lua`

- Apps menu moved from `SUPER+ALT+SPACE` to `SUPER+D`
- Norwegian keyboard layout, flat mouse acceleration
- Both AOC monitors (matched by description, so ports can change)
- No window rounding, dim inactive windows, full opacity

### Setup

```sh
../../dotfiles.bash adopt       # first time: move the live files into the repo, then link
../../dotfiles.bash link        # later: link the profile (shell.json, plugins, hypr settings)
../../dotfiles.bash setup       # hyprland.lua hook, plugin hooks (needs the links)
../../dotfiles.bash uninstall   # remove the hooks; `unlink` removes the links
```

Safe to run again; do so after `omarchy refresh hyprland` or `omarchy refresh shell`.
Each file is its own link, so Omarchy's other files in `~/.config/hypr/` and
`~/.config/omarchy/` stay untouched. If Omarchy edits a linked file such as
`shell.json`, the change shows up in `git diff`. If it does not, Omarchy replaced
the link with a real file: run `adopt`, then check `git diff`.
Before the first `adopt`, remove the old `~/.config/hypr/solo-workspaces.lua`
link that the copy-based `setup` made; stow does not replace a link it does not own.
Every folder in `plugins/` is hooked into `~/.config/hypr/autostart.lua`.

What it does by hand: `custom.lua` is loaded from `~/.config/hypr/hyprland.lua`, which needs two edits:

1. Before `require("default.hypr.omarchy")`, uncomment:

   ```lua
   omarchy_preinstalled_bindings = false
   ```

2. At the end, add:

   ```lua
   dofile(os.getenv("HOME") .. "/Projects/dotfiles/profiles/omarchy/hypr/custom.lua")
   ```

Then check with `hyprctl reload && hyprctl configerrors`. Redo both edits after
`omarchy refresh hyprland`, which resets `hyprland.lua`.

## Not included on purpose

Omarchy's default `~/.config/hypr` files, `gh/` (auth token), `*.bak*`
backups, browser and app state.
