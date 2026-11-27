# Dotfiles: project guide and dotfiles.bash usage

What is in this repo, how a machine gets set up, and every `dotfiles.bash`
command. `./dotfiles.bash help` prints the short version.

## Project layout

```text
dotfiles.bash          links common/ + the active profile into ~/.config (GNU stow), Omarchy setup, NixOS rebuild
tests.bash             every test: dotfiles.bash in a temp HOME, profile dry runs, plugin tests
flake.nix, flake.lock  NixOS flake (system + home-manager), reads common/ and profiles/nixos/
common/                app configs every profile links (terminals, fish, git, nvim, yazi, zed)
profiles/
  <os>/                what only that OS links or overrides (omarchy, nixos, ubuntu...)
    <folder>/          one app or area, linked into ~/.config/<folder>/
    packages.txt       packages `bootstrap` installs (never linked)
    README.md          notes for that OS (never linked)
machines/<host>/       snapshots of per-machine files (`snapshot`), not linked
docs/                  this guide
fixes/                 documented local patches for upstream bugs
.github/workflows/     CI: shellcheck, tests.bash, Prettier, gitleaks, Nix evaluation
```

| Folder              | What                                                                    | More                                      |
| ------------------- | ----------------------------------------------------------------------- | ----------------------------------------- |
| `common/`           | Terminals (alacritty, kitty, foot, ghostty), fish, nvim, yazi, zed, git | [README](../common/README.md)             |
| `profiles/omarchy/` | Omarchy (Hyprland): `hypr/custom.lua`, per-host monitors, shell plugins | [README](../profiles/omarchy/README.md)   |
| `profiles/nixos/`   | NixOS: MangoWM + Noctalia, and `nix/` (system, home-manager)            | [README](../profiles/nixos/nix/README.md) |
| `fixes/`            | Patches applied outside package management, each with revert and verify | [README](../fixes/README.md)              |

## How it works

`dotfiles.bash link` runs GNU stow twice: on `common/`, then on the active
profile. `common/kitty/kitty.conf` becomes the link `~/.config/kitty/kitty.conf`.

- **The profile wins.** A file in `profiles/<os>/` with the same path as one in
  `common/` replaces it (Omarchy's LazyVim `nvim/init.lua` replaces the plain
  one). Everything else in `common/` is linked next to the profile's files.
- **One link per file.** Folders in `~/.config` stay real folders, so files the
  repo does not track (Omarchy's own files in `~/.config/hypr/`, app state) stay untouched.
- **The repo is the live copy.** Editing a file in `~/.config` edits the repo, and
  git does the rest: history, sync between machines, backups and undo.
- **Stow never overwrites.** If a real file is in the way, `link` stops and names
  it. Use `adopt` (once) or `track` to bring it into the repo.
- **Never linked:** `README.md` at any depth, `fish_variables`, a profile's
  `packages.txt`.
- **Per-machine files** that apps rewrite (`omarchy/shell.json`,
  `hypr/bindings.lua`, `hypr/monitors.lua`) stay real files; `snapshot` backs
  them up to `machines/<host>/`.

## Setting up a machine

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./dotfiles.bash bootstrap
```

`bootstrap` installs `profiles/<os>/packages.txt`, links `common/` and the
profile, runs `setup` on Omarchy, then `doctor`. On NixOS it runs `rebuild`.
If the machine already has configs in `~/.config`, run `adopt` first (it moves
them into the repo; review with `git diff`, `git restore` what you do not want).

For another OS, make `profiles/<os>/` (it can start empty: `common/` is linked
anyway), add only what differs, then `link -n` to preview and `link`.

## Commands

| Command                | What it does                                                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bootstrap`            | New machine: install `packages.txt`, `link`, `setup` (Omarchy), `doctor`. NixOS: `rebuild`.                                                                        |
| `link [-n]`            | Link `common/` and the profile into `~/.config`. `-n` shows what stow would do and changes nothing. Safe to repeat; run it after adding files or after `git pull`. |
| `adopt`                | Like `link`, but a real file in the way is moved into the repo first (stow `--adopt`). Review with `git diff`; `git restore` puts the repo version back.           |
| `unlink`               | Remove the links. The repo keeps the files.                                                                                                                        |
| `track PATH..`         | Move files or folders from `~/.config` into the profile and link them back. PATH is relative to `~/.config` or absolute under it. Commit afterwards.               |
| `doctor`               | Report broken links into the repo, repo files that are not linked, and anything that would stop `link`. Exits 1 if something needs fixing.                         |
| `snapshot`             | Copy per-machine files to `machines/<host>/`. Commit to keep them.                                                                                                 |
| `setup`                | Omarchy: load `custom.lua` from `hyprland.lua` and build `benjy.bar`. Run after `link`; safe to repeat.                                                            |
| `uninstall`            | Omarchy: remove that hook. The links stay until `unlink`.                                                                                                          |
| `bar-update`           | Omarchy: rebuild `benjy.bar` from the stock bar plus `bar.patch`. Stops, leaving the live bar alone, if the patch no longer applies.                               |
| `bar-save`             | Omarchy: save edits to the live `benjy.bar/Bar.qml` as `bar.patch`.                                                                                                |
| `rebuild [-n]`         | NixOS: `nixos-rebuild switch` for this repo's flake (`-n`: dry-build).                                                                                             |
| `profile [NAME\|auto]` | Show the active profile, or save a choice for this machine.                                                                                                        |

On a profile with a `nix/` folder, `link`, `adopt` and `unlink` refuse and point at `rebuild`.

## Everyday work

- **See what changed:** `but status` / `but diff` (or `git status`, `git diff`).
- **Throw a tweak away:** `but discard <id>` (or `git restore <file>`).
- **Get changes from another machine:** pull, then `./dotfiles.bash link`.
- **Something looks off:** `./dotfiles.bash doctor`.
- **Before committing:** `./tests.bash`.

## Profiles

The active profile is, in order: `DOTFILES_PROFILE`, the choice saved by
`profile NAME` (`~/.local/state/dotfiles/profile`), then detection (Omarchy if
`~/.config/omarchy` exists, NixOS, then `ID`/`ID_LIKE` from `/etc/os-release`;
only profiles that exist can match). `profile auto` goes back to detection.

## Omarchy

- `hypr/custom.lua` holds the settings every Omarchy machine shares and is
  loaded from `~/.config/hypr/hyprland.lua` (`setup` adds that line). It loads
  `hypr/hosts/<hostname>.lua` (monitors, HDR) and each plugin's Hyprland Lua.
- Plugins live in `omarchy/plugins/` and are linked into `~/.config/omarchy/plugins/`.
- `benjy.bar` keeps only its own files and `bar.patch` in the repo; `setup` and
  `bar-update` build the rest from Omarchy's bar. After an Omarchy update, run
  `bar-update`.
- More in [profiles/omarchy/README.md](../profiles/omarchy/README.md).

## NixOS

NixOS needs no links from `dotfiles.bash`. `nixos-rebuild` reads the configs
straight from this repo and home-manager links them into `~/.config`.

- Edit, then `./dotfiles.bash rebuild` (`-n` does a dry build). It runs
  `nixos-rebuild switch --flake <repo>#<host> --impure --sudo`, where host is the
  `profiles/nixos/nix/hosts/` folder named like this machine (else the first
  one); set `DOTFILES_NIX_HOST` to override.
- Every folder of `common/` and `profiles/nixos/` (except `nix/`) is deployed by
  `profiles/nixos/nix/dotfiles.nix`. A profile folder replaces the whole common
  folder of the same name. `profiles/nixos/profile.conf` picks one app per group
  (terminal, window manager...); only the picked one is deployed.
- More in [profiles/nixos/nix/README.md](../profiles/nixos/nix/README.md).

## Environment variables

| Variable             | Meaning                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `DOTFILES_PROFILE`   | Force a profile (or `auto`) for one run.                           |
| `DOTFILES_NIX_HOST`  | Flake host for `rebuild`.                                          |
| `DOTFILES_HOST`      | Host name for `snapshot` instead of `hostname`.                    |
| `DOTFILES_STOCK_BAR` | Stock bar for `bar-update` (tests).                                |
| `XDG_CONFIG_HOME`    | Link target instead of `~/.config`.                                |
| `XDG_STATE_HOME`     | Where the saved profile choice lives, instead of `~/.local/state`. |

## Requirements

`bash`, `git`, GNU `stow`, `patch`. `hyprctl` for Omarchy `setup`;
`nixos-rebuild` for `rebuild`; `lua` and `node` for the plugin tests.

## Troubleshooting

- **"stow not found":** `sudo pacman -S stow` (or `bootstrap`).
- **"no profile for this machine":** run `./dotfiles.bash profile NAME`, or make
  the profile folder.
- **`link` stops with "existing target is neither a link nor a directory":** a
  real file is in the way. Run `adopt` to take it into the repo (then check
  `git diff`), or move it away and run `link` again.
- **`link` stops on "source is an absolute symlink":** a file in the repo is a
  link to an absolute path; stow refuses those. Replace it with the real file.
- **An app replaced a link with a real file:** some apps save by writing a new
  file. `doctor` lists it as not linked; run `adopt`, then `git diff`.
- **The bar disappeared after an Omarchy update:** `./dotfiles.bash bar-update`.
- **Hyprland errors after `setup`:** `hyprctl configerrors`; `uninstall` removes the hook.
