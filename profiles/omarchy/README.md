# Omarchy

Personal Omarchy (Hyprland + Quickshell) changes. Only files I changed are
tracked; everything else stays Omarchy's stock config.

| Path                                                                                        | Lives at                       | What                                                                                                                                 |
| ------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `hypr/custom.lua`                                                                           | loaded from here (also linked) | Hyprland settings every Omarchy machine shares (see below)                                                                           |
| `hypr/hosts/<hostname>.lua`                                                                 | linked to `~/.config/hypr/`    | Monitors and HDR of one machine, loaded by `custom.lua` when the hostname matches                                                    |
| `hypr/solo-workspaces.lua`                                                                  | linked to `~/.config/hypr/`    | My settings for the solo-workspaces plugin: the solo apps (Jellyfin)                                                                 |
| `git/profile`                                                                               | linked to `~/.config/git/`     | SSH commit signing, included by `common/git/config`                                                                                  |
| `nvim/`                                                                                     | linked to `~/.config/nvim/`    | LazyVim; replaces the plain `common/nvim/init.lua`                                                                                   |
| [`omarchy/plugins/benjy.solo-workspaces/`](omarchy/plugins/benjy.solo-workspaces/README.md) | `~/.config/omarchy/plugins/`   | Listed apps get a workspace to themselves, moved to the nearest empty one                                                            |
| [`omarchy/plugins/benjy.workspaces/`](omarchy/plugins/benjy.workspaces/README.md)           | `~/.config/omarchy/plugins/`   | Workspace groups: 3 groups of 10 per monitor (`SUPER+PgDn/PgUp`), and a bar widget (clone of `omarchy.workspaces`) showing `G1`-`G3` |
| [`omarchy/plugins/benjy.bar/`](omarchy/plugins/benjy.bar/README.md)                         | `~/.config/omarchy/plugins/`   | Auto-hiding bar for OLED (`omarchy.bar` + `bar.patch`): peeks on Super hold, top-edge hover and workspace switch                     |
| [`omarchy/plugins/benjy.oled-idle/`](omarchy/plugins/benjy.oled-idle/README.md)             | `~/.config/omarchy/plugins/`   | Screens off after 3 min idle and 15 s into the lock screen                                                                           |
| `packages.txt`                                                                              | not linked                     | What `./dotfiles.bash bootstrap` installs                                                                                            |

The rest of the shared configs (terminals, fish, git, yazi, zed) come from
[`common/`](../../common/README.md). `~/.config/omarchy/shell.json` (bar layout,
plugins, idle) stays a per-machine file; `./dotfiles.bash snapshot` backs it up
to `machines/<host>/`.

## `hypr/custom.lua`

- Apps menu moved from `SUPER+ALT+SPACE` to `SUPER+D`
- Norwegian keyboard layout, flat mouse acceleration, Bibata cursor
- No window rounding, gaps or borders; blur behind see-through windows
- Steam games tiled and kept awake, GitButler floating, tearing for Star Citizen
- Floating windows left off every monitor are moved back
- Loads `hypr/hosts/<hostname>.lua` and the plugins' Hyprland Lua

### Setup

```sh
../../dotfiles.bash bootstrap   # new machine: packages, link, setup, doctor
../../dotfiles.bash link        # link common/ and this profile
../../dotfiles.bash setup       # hyprland.lua hook, build benjy.bar (needs the links)
../../dotfiles.bash uninstall   # remove the hook; `unlink` removes the links
```

Safe to run again; do so after `omarchy refresh hyprland`. Each file is its own
link, so Omarchy's other files in `~/.config/hypr/` and `~/.config/omarchy/`
stay untouched. A new plugin with Hyprland-side Lua gets one `dofile` line at
the end of `custom.lua`.

What `setup` does by hand: `custom.lua` is loaded from `~/.config/hypr/hyprland.lua`, which needs two edits:

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
