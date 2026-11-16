# Dotfiles: project guide and dotfiles.bash usage

What is in this repo, how a machine gets set up, and every `dotfiles.bash`
command. `./dotfiles.bash help` prints the short version.

## Contents

- [Project layout](#project-layout)
- [How it works](#how-it-works)
- [Setting up a machine](#setting-up-a-machine)
- [Commands](#commands)
- [Everyday work with git](#everyday-work-with-git)
- [Profiles](#profiles)
- [Omarchy](#omarchy)
- [NixOS](#nixos)
- [Other folders](#other-folders)
- [Environment variables](#environment-variables)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)

## Project layout

```text
dotfiles.bash          links the active profile into ~/.config (GNU stow), Omarchy setup, NixOS rebuild
tests.bash             black-box tests for dotfiles.bash in a temp HOME
flake.nix, flake.lock  NixOS flake (system + home-manager), reads profiles/nixos/
profiles/
  <os>/                what a machine with that OS links (omarchy, nixos, ubuntu...)
    <folder>/          one app or area, linked into ~/.config/<folder>/
    README.md          notes for that OS (optional, never linked)
apps/                  boilerplate app configs to copy into a new profile
mango/                 boilerplate MangoWM + Noctalia config
docs/                  this guide
fixes/                 documented local patches for upstream bugs
```

| Folder | What | More |
|---|---|---|
| `profiles/omarchy/` | Omarchy (Hyprland): apps, `hypr/custom.lua`, workspace plugins, `shell.json` | [README](../profiles/omarchy/README.md) |
| `profiles/nixos/` | NixOS: apps, MangoWM, and `nix/` (system, home-manager) | [README](../profiles/nixos/nix/README.md) |
| `apps/` | Terminals (alacritty, kitty, foot, ghostty), fish, nvim, yazi, zed, git | [README](../apps/README.md) |
| `mango/` | MangoWM compositor with Noctalia: keys, monitors, look | [README](../mango/README.md) |
| `fixes/` | Patches applied outside package management, each with revert and verify | [README](../fixes/README.md) |

## How it works

`dotfiles.bash link` runs GNU stow on the active profile:
`profiles/<os>/kitty/kitty.conf` becomes the link `~/.config/kitty/kitty.conf`.

- **One link per file.** Folders in `~/.config` stay real folders, so files the
  repo does not track (Omarchy's own files in `~/.config/hypr/`, app state) stay untouched.
- **The repo is the live copy.** Editing a file in `~/.config` edits the repo, and
  git does the rest: history, sync between machines, backups and undo.
- **Stow never overwrites.** If a real file is in the way, `link` stops and names
  it. Use `adopt` (once) or `track` to bring it into the repo.
- **`README.md` files are never linked**, at any depth.

## Setting up a machine

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
sudo pacman -S stow
```

- **Omarchy:** `./dotfiles.bash adopt` moves the files already in `~/.config` into
  the repo and links them. Review with `git diff`, `git restore` what you do not want,
  then `./dotfiles.bash setup` (Hyprland hooks). See [Omarchy](#omarchy).
- **NixOS:** `./dotfiles.bash rebuild`. No links needed; see [NixOS](#nixos).
- **A clean machine or another OS:** make the profile (copy folders from `apps/` into
  `profiles/<os>/`), then `./dotfiles.bash link -n` to preview and `link`.

## Commands

| Command | What it does |
|---|---|
| `link [-n]` | Link the profile into `~/.config`. `-n` shows what stow would do and changes nothing. Safe to repeat; run it after adding files to the profile or after `git pull`. |
| `adopt` | Like `link`, but a real file in the way is moved into the repo first (stow `--adopt`), so the live version wins. Review with `git diff`; `git restore` puts the repo version back. Meant for the first run on a machine. |
| `unlink` | Remove the links. The repo keeps the files; `~/.config` loses them until the next `link`. |
| `track PATH..` | Move files or folders from `~/.config` into the profile and link them back. PATH is relative to `~/.config` (`kitty/kitty.conf`) or absolute under it. Refuses a link, a path outside `~/.config`, and a path the repo already has. Commit afterwards. |
| `setup` | Omarchy: hook `custom.lua` and the plugins into Hyprland. Run after `link`. |
| `uninstall` | Omarchy: remove those hooks. The links stay until `unlink`. |
| `rebuild [-n]` | NixOS: `nixos-rebuild switch` for this repo's flake (`-n`: dry-build). |
| `profile [NAME\|auto]` | Show the active profile, or save a choice for this machine. |
| `help` | Print the command list. |

On a profile with a `nix/` folder, `link`, `adopt` and `unlink` refuse and point at `rebuild`.

## Everyday work with git

- **See what changed:** `git status`, `git diff`.
- **Keep a tweak:** `git commit -am "kitty: bigger font"`, then `git push`.
- **Throw a tweak away:** `git restore profiles/omarchy/kitty/kitty.conf`.
- **Get changes from another machine:** `git pull`, then `./dotfiles.bash link`
  for any new files.
- **Stop tracking a file:** `./dotfiles.bash unlink`, `git mv` or copy the file back
  to `~/.config`, remove it from the profile, then `link`.

## Profiles

```text
profiles/
  omarchy/   kitty/  git/  hypr/  omarchy/ ...
  ubuntu/    kitty/  git/ ...
```

The active profile is, in order: `DOTFILES_PROFILE`, the choice saved by
`profile NAME` (`~/.local/state/dotfiles/profile`), then detection (Omarchy if
`~/.config/omarchy` exists, NixOS, then `ID`/`ID_LIKE` from `/etc/os-release`;
only profiles that exist can match). `profile auto` goes back to detection.

To add an OS, make `profiles/ubuntu/` and copy the folders you want from `apps/`
(`cp -r apps/kitty apps/git profiles/ubuntu/`), edit them, then `link` and commit.

## Omarchy

On a profile with `hypr/custom.lua` and `omarchy/plugins/`, `link` places the
plugin files in `~/.config/omarchy/plugins/` and the settings files (like
`hypr/solo-workspaces.lua`) in `~/.config/hypr/`. Then:

- `setup` loads `custom.lua` from `~/.config/hypr/hyprland.lua` and hooks every
  plugin into `~/.config/hypr/autostart.lua` (it creates that file and its
  `require` if needed). It keeps `hyprland.lua.bak` and `autostart.lua.bak`.
  Safe to repeat, e.g. after `omarchy refresh hyprland`.
- `uninstall` removes the hooks.

Moving from the old copy-based `dotfiles.bash`: remove the
`~/.config/hypr/solo-workspaces.lua` link it made, then run `adopt` and review `git diff`.

## NixOS

NixOS needs no links from `dotfiles.bash`. `nixos-rebuild` reads the configs
straight from this repo (`profiles/nixos/`) and home-manager links them into
`~/.config`.

- Edit files in `profiles/nixos/`, then run `./dotfiles.bash rebuild` (`-n` does a
  dry build). It runs `nixos-rebuild switch --flake <repo>#<host> --impure --sudo`,
  where host is the `profiles/nixos/nix/hosts/` folder named like this machine
  (else the first one); set `DOTFILES_NIX_HOST` to override.
- Every folder in `profiles/nixos/` (except `nix/`) is deployed by
  `profiles/nixos/nix/dotfiles.nix`. `profiles/nixos/profile.conf` picks one app
  per group (terminal, window manager...); only the picked one is deployed.
- More in [profiles/nixos/nix/README.md](../profiles/nixos/nix/README.md).

## Other folders

- **`apps/`:** boilerplate. Terminals share one look (JetBrainsMono Nerd Font, same
  keys); `nvim` is a plugin-free `init.lua`; `git` holds aliases and defaults.
- **`mango/`:** MangoWM config (`config.conf`, `conf.d/`, `scripts/`, `wall/`).
  `noctalia.conf` is generated and never tracked.
- **`fixes/`:** one numbered folder per fix (`NNN-slug/`) with a README (symptom,
  cause, versions, undo), the patch, snapshots of live files, a `verify/` check and
  `revert.sh`. Nothing runs automatically.
- **Omarchy plugins:** `benjy.solo-workspaces` (listed apps get a
  workspace of their own; settings are `hypr/solo-workspaces.lua`) and
  `benjy.workspaces` (workspace groups per monitor, plus their bar widget).
  Linked by `link`, hooked by `setup`.

## Environment variables

| Variable | Meaning |
|---|---|
| `DOTFILES_PROFILE` | Force a profile (or `auto`) for one run. |
| `DOTFILES_NIX_HOST` | Flake host for `rebuild`. |
| `XDG_CONFIG_HOME` | Link target instead of `~/.config`. |
| `XDG_STATE_HOME` | Where the saved profile choice lives, instead of `~/.local/state`. |

## Requirements

`bash`, `git`, GNU `stow`. `hyprctl` for Omarchy `setup`; `nixos-rebuild` for `rebuild`.

## Troubleshooting

- **"stow not found":** `sudo pacman -S stow`.
- **"no profile for this machine":** no `profiles/<os>/` matches. Run
  `./dotfiles.bash profile NAME`, or make the profile folder.
- **`link` stops with "existing target is neither a link nor a directory":** a
  real file is in the way. Run `adopt` to take it into the repo (then check
  `git diff`), or move it away and run `link` again.
- **`link` stops on a link stow does not own:** an old link (for example from the
  copy-based script) is in the way. Remove it and run `link` again.
- **An app replaced a link with a real file:** some apps save by writing a new
  file. Run `adopt`, then `git diff` to see what changed.
- **Hyprland errors after `setup`:** `hyprctl configerrors`; `uninstall` removes the hooks.
