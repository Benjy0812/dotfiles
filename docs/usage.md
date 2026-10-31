# Dotfiles: project guide and dotfiles.bash usage

Everything about this repo in one place: what is in it, how a machine gets set
up, and every `dotfiles.bash` command. `./dotfiles.bash help` prints a short
version of the usage part.

## Contents

- [Project layout](#project-layout)
- [Setting up a machine](#setting-up-a-machine)
- [Concepts](#concepts)
- [Quick start](#quick-start)
- [The menu](#the-menu)
- [Commands](#commands)
- [Options](#options)
- [Names](#names)
- [Profiles](#profiles)
- [Profile settings](#profile-settings)
- [Config files](#config-files)
- [Backups and undo](#backups-and-undo)
- [Omarchy](#omarchy)
- [NixOS](#nixos)
- [Other folders](#other-folders)
- [Files on disk](#files-on-disk)
- [Environment variables](#environment-variables)
- [Requirements](#requirements)
- [Recipes](#recipes)
- [Troubleshooting](#troubleshooting)

## Project layout

```text
dotfiles.bash          the one script: sync, backups, undo, profiles, Omarchy setup
flake.nix, flake.lock  NixOS flake (system + home-manager), reads profiles/nixos/
profiles/
  <os>/                what a machine with that OS syncs (omarchy, nixos, ubuntu...)
    <folder>/          one app or area, goes to ~/.config/<folder>/
    profile.conf       preferred terminal and editor (optional)
    .dotfiles-map      where folders go (optional)
    .dotfiles-hosts    which folders a hostname gets (optional)
    .dotfilesignore    paths to skip, local, not committed (optional)
    README.md          notes for that OS (optional)
apps/                  boilerplate app configs, copied by `profile new`
mango/                 boilerplate MangoWM + Noctalia config, copied by `profile new`
docs/                  this guide
fixes/                 documented local patches for upstream bugs
```

Rule: nothing is synced from the repo root. A machine syncs only its own
profile; `apps/` and `mango/` are starting points to copy from.

| Folder | What | More |
|---|---|---|
| `profiles/omarchy/` | Omarchy (Hyprland): apps, `hypr/custom.lua`, two workspace plugins, `shell.json` | [README](../profiles/omarchy/README.md) |
| `profiles/nixos/` | NixOS: apps, MangoWM, and `nix/` (system, home-manager) | [README](../profiles/nixos/nix/README.md) |
| `apps/` | Terminals (alacritty, kitty, foot, ghostty), fish, nvim, yazi, zed, git | [README](../apps/README.md) |
| `mango/` | MangoWM compositor with Noctalia: keys, monitors, look | [README](../mango/README.md) |
| `fixes/` | Patches applied outside package management, each with revert and verify | [README](../fixes/README.md) |

## Setting up a machine

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

- **Omarchy:** `./dotfiles.bash push -n` to preview, `push`, then `setup` (hyprland
  hook, settings links, plugins).
- **NixOS:** `nixos-rebuild switch --flake ~/Projects/dotfiles#<host> --sudo` (a folder in `profiles/nixos/nix/hosts/`). No
  sync needed; see [NixOS](#nixos).
- **Another OS (Ubuntu, Arch...):** `./dotfiles.bash profile new ubuntu kitty git fish nvim`,
  edit `profiles/ubuntu/` to fit, then `push`. Commit the new profile.
- **Anywhere, one app only:** `./dotfiles.bash push kitty`.

## Concepts

- **Profile:** `profiles/<os>/` (omarchy, nixos, ubuntu...). Only the active
  profile is synced. `apps/` and `mango/` are boilerplate that `profile new` copies.
- **Folder:** each folder in the profile goes to `~/.config/<folder>/`
  (change with the profile's `.dotfiles-map`).
- **State of a file:**
  - `in sync`: identical on both sides.
  - `edited in ~/.config` (`← save to repo`): only `~/.config` changed since the last sync.
  - `newer in repo` (`→ save to ~/.config`): only the repo changed.
  - `changed on both sides`: both changed; you choose.
  - `not installed`: missing from `~/.config`.
- **Baseline:** for each file the script saves a checksum from the last time both
  sides matched (`~/.local/state/dotfiles/synced.tsv`). Every push or pull updates it.
  Without one it guesses from modification times and cannot see conflicts.

## Quick start

```bash
./dotfiles.bash            # open the menu
./dotfiles.bash status     # what differs
./dotfiles.bash push -n    # dry run
./dotfiles.bash push       # repo -> ~/.config (old files kept as backups)
./dotfiles.bash pull       # ~/.config -> repo
./dotfiles.bash undo --yes # reverse the last run
```

## The menu

Needs `gum`; the pickers need `fzf`. The header shows the status table and a
"Next:" line saying what to do.

| Entry | What it does |
|---|---|
| **Sync** | One list of every differing file. Safe files start ticked, conflicts unticked. Enter shows a review screen, then applies each file in the direction shown. Keys: `Tab` toggle, `Ctrl-a` all, `Ctrl-d` none, `Ctrl-e` open `nvim -d`. A conflict asks: keep repo copy, keep `~/.config` copy, merge in nvim, or skip. After pulls you can commit and push. |
| **Backups** | Restore a backup (type a folder or file name to filter; diff preview) or delete backups older than 7, 30 or 90 days. |
| **Choose what syncs** | Tick the files that should sync; unticked ones go into `.dotfilesignore`. |
| **Undo last sync** | Appears once something was applied. |
| **Tools** | Profile, Doctor, and (on Omarchy profiles) set up / uninstall. |

## Commands

Everyday:

| Command | Description |
|---|---|
| *(none)* | Open the menu. |
| `status` | One row per folder with counts and skipped files. `--json` for scripts. |
| `diff [name..]` | Colored diff: `-` repo, `+` `~/.config`. |
| `push [name..]` | Copy repo to `~/.config`. A different existing file is moved to the backup folder first. |
| `pull [name..]` | Copy edited files into the repo. Conflicts are skipped unless named. `--commit` commits the pulled files (no push). |
| `restore [NAME/FILE..]` | Bring back the newest backup; without names pick one with fzf. The current file is backed up first. |
| `skipped` | List every file and folder that is not synced and why: built-in skips, `.dotfilesignore` patterns, and apps not picked in a group. Also in Tools > What is skipped. |
| `select` | The "Choose what syncs" picker. |
| `undo [--yes]` | Lists, then with `--yes` reverses the last push, pull or restore. Undoing is itself undoable. |

More:

| Command | Description |
|---|---|
| `fetch` | List every differing file with `+/-` line counts; changes nothing. |
| `merge NAME FILE` | Open both copies in `nvim -d`; save into the side to keep, then push or pull. |
| `backups` | List all backups of tracked files. |
| `clean [DAYS]` | List backups older than DAYS (default 30); `--yes` deletes them. |
| `baseline` | Record every file that is in sync as the common starting point. Rarely needed. |
| `doctor` | Check tools, `.gitignore`, broken links, old backups, sync record, profile. |
| `watch [--auto] [name..]` | Notify when a tracked file is saved in `~/.config`; `--auto` pulls it. Needs `inotify-tools`. |
| `setup` / `uninstall` | Omarchy hook, links and plugins (see [Omarchy](#omarchy)). |
| `profile` | Show the active and available profiles. |
| `profile NAME\|auto\|none` | Choose this machine's profile. |
| `profile new NAME [folder..]` | Create a profile by copying boilerplate (all of `apps/` if no folders named). |
| `profile set GROUP NAME\|all` | Pick the app of a group to sync (terminal, editor, shell...). |
| `profile group GROUP NAME NAME..` | Define a group of alternatives in `profile.conf`. |
| `rebuild` | NixOS only: `nixos-rebuild switch` for this flake (`-n` dry-build). |
| `edit [NAME[/FILE]]` | Open the profile in the preferred editor. |
| `profile templates` | List the boilerplate folders. |
| `map` | Show where each folder goes. |
| `list [files]` | Folder names, or every `NAME/FILE`. |
| `preview NAME FILE` | Diff of one file (used by the pickers). |
| `help`, `version` | |

## Options

| Option | Effect |
|---|---|
| `-n`, `--dry-run` | Show what would happen; change nothing. |
| `-y`, `--yes` | Let `clean` and `undo` act. |
| `--json` | `status` as JSON. |
| `--commit` | `pull`: commit the pulled files. |
| `-h`, `-v` | Same as `help`, `version`. |

`NO_COLOR=1` turns colors off.

## Names

A name is a folder (`fish`) or a file (`fish/config.fish`). Without names:
`push` and `diff` use every out-of-sync folder; `pull` uses every folder with
edits in `~/.config`.

## Profiles

```text
profiles/
  omarchy/   kitty/  git/  hypr/  omarchy/ ...
  ubuntu/    kitty/  git/ ...
```

The active profile is, in order: `DOTFILES_PROFILE`, the choice saved by
`profile NAME` (`~/.local/state/dotfiles/profile`), then detection (Omarchy if
`~/.config/omarchy` exists, NixOS, then `ID`/`ID_LIKE` from `/etc/os-release`;
only profiles that exist can match). With no match nothing is synced.
A profile that contains a `nix/` folder (the `nixos` one) is deployed by
home-manager through `nixos-rebuild`, so `dotfiles.bash` never syncs it.

To add an OS: `./dotfiles.bash profile new ubuntu kitty git fish`, then edit
`profiles/ubuntu/`. The copy is independent of `apps/` and other profiles.

## Profile settings

`profiles/<os>/profile.conf` defines groups of alternative apps and picks one per
group. A profile can hold every terminal, editor, shell and so on, but only the
picked one of each group is synced (and, on NixOS, deployed); the rest stay
untouched in the profile folder.

```text
group.terminal = alacritty kitty foot ghostty   # defines a group
group.editor   = nvim zed
group.shell    = fish zsh bash nushell elvish xonsh
terminal = kitty                                # picks one (or "all")
editor = nvim
shell = fish
```

- Groups are per profile, so each OS can have its own alternatives, and you can
  add any: `./dotfiles.bash profile group launcher rofi wofi`, then
  `./dotfiles.bash profile set launcher rofi`. Members are folder names.
- `profile new` writes starter groups (terminal, editor, wm, shell) with every
  group set to `all`. Use `all` (or leave the choice out) to sync every member.
- Change a pick with `./dotfiles.bash profile set GROUP NAME`, or Tools > Profile
  settings in the menu. `./dotfiles.bash profile` lists the groups and picks.
- Status shows what is not synced, e.g. `terminal: kitty (alacritty, foot, ghostty not synced)`.
  If the picked app isn't in the profile, nothing is filtered.
- `dotfiles.nix` reads the same file, so NixOS and `dotfiles.bash` agree.

`./dotfiles.bash edit [NAME[/FILE]]` opens the profile (or one folder or file of
it) in the editor picked in the `editor` group, falling back to `$EDITOR`, then `nvim`.

### Choosing what syncs: which tool

| You want to... | Use |
|---|---|
| Keep a whole app out of a machine | Leave its folder out of the profile (`profile new` with only the folders you need, or delete it) |
| Sync only one app of a group (terminal, editor, shell, wm...) | `profile set terminal kitty` / Tools > Profile settings |
| Give different hostnames different folders | `.dotfiles-hosts` |
| Skip one file inside a folder you keep (e.g. `omarchy/shell.json`) | `select` (menu: Choose what syncs), fine-grained |
| Skip a pattern (e.g. `mango/wall/*`) | Edit `.dotfilesignore` by hand |

Start with the folder-level options and use `select` only for single files.

## Config files

All optional, and per profile: they live in `profiles/<os>/`, never in the repo
root, so each OS has its own.

- **`profiles/<os>/.dotfilesignore`** (local, not committed): paths to skip, one
  glob per line (`folder/file`, `*` matches slashes, `#` comments). Edited by
  `select`. Always skipped: `*/README.md`, `*/fish_variables`, `hypr/custom.lua`.
- **`profiles/<os>/.dotfiles-map`**: `folder/path = target`, longest match wins,
  `~` is home. Default is `~/.config/<folder>/`.
  ```text
  kitty/themes = ~/.local/share/kitty-themes
  ```
- **`profiles/<os>/.dotfiles-hosts`**: `hostname: folder folder` limits which
  folders a machine gets; `*` or no line means all. Find the name with `uname -n`.

## Backups and undo

- Replaced `~/.config` files go to
  `~/.local/state/dotfiles/backups/<folder>/<file>/<timestamp>`. Pulls overwrite
  repo files without a backup; git is the undo there (and `undo` keeps a copy).
- Every push, pull and restore is a run logged in `history.tsv`. `undo` reverses
  the newest run: puts back replaced files, moves created files into backups,
  restores repo files a pull overwrote.
- Backups age from the day they were made. Clean them with `clean` or the menu.

## Omarchy

On a profile with `hypr/custom.lua` and `omarchy/plugins/`:

- `setup` loads `custom.lua` from `~/.config/hypr/hyprland.lua`, links the
  settings files (`hypr/*.lua` except `custom.lua`) into `~/.config/hypr/`,
  installs every plugin and hooks it into `bindings.lua` (plugins with a
  `Widget.qml`, which also replace the bar's workspace widget) or `autostart.lua`.
  Safe to repeat, e.g. after `omarchy refresh hyprland`.
- `uninstall` removes all of that. Settings stay in the repo.

## NixOS

NixOS needs no sync. `nixos-rebuild` reads the configs straight from this repo
(`profiles/nixos/`) and home-manager links them into `~/.config`, so the repo is
the only copy. That is why `dotfiles.bash` skips any profile that contains a
`nix/` folder: status says "managed by Nix" and push, pull and the menu do nothing.

- Edit files in `profiles/nixos/`, then rebuild with `./dotfiles.bash rebuild`
  (or Tools > NixOS: rebuild; `-n` does a dry build). It runs
  `nixos-rebuild switch --flake <repo>#<host> --sudo`, where host is the
  `profiles/nixos/nix/hosts/` folder named like this machine (else the first one);
  set `DOTFILES_NIX_HOST` to override.
- Every folder in `profiles/nixos/` (except `nix/`) is deployed automatically by
  `profiles/nixos/nix/dotfiles.nix`: add a folder, rebuild, done. It also
  honors `profile.conf`, so only the picked app of each group is deployed. The other config files
  (`.dotfiles-map`, `.dotfiles-hosts`, `.dotfilesignore`) are not used on NixOS,
  because `dotfiles.bash` never syncs this profile; only `profile.conf` matters here.
- More in [profiles/nixos/nix/README.md](../profiles/nixos/nix/README.md).

## Other folders

- **`apps/`:** boilerplate. Terminals share one look (JetBrainsMono Nerd Font, same
  keys); `nvim` is a plugin-free `init.lua`; `git` holds aliases and defaults.
- **`mango/`:** MangoWM config (`config.conf`, `conf.d/`, `scripts/`, `wall/`).
  `noctalia.conf` is generated and never tracked.
- **`fixes/`:** one numbered folder per fix (`NNN-slug/`) with a README (symptom,
  cause, versions, undo), the patch, snapshots of live files, a `verify/` check and
  `revert.sh`. Nothing runs automatically.
- **Omarchy plugins:** `benjy.monitor-workspaces` (workspaces 1-10 on every
  monitor, with bar widget) and `benjy.solo-workspaces` (listed apps get a
  workspace of their own). Installed by `setup`; settings are `hypr/*-workspaces.lua`.

## Files on disk

| Path | What |
|---|---|
| `~/.local/state/dotfiles/synced.tsv` | Baseline: checksum of each file at its last sync |
| `~/.local/state/dotfiles/history.tsv` | Log of every push, pull and restore (for `undo`) |
| `~/.local/state/dotfiles/backups/` | Replaced `~/.config` files, per folder and file |
| `~/.local/state/dotfiles/undo/` | Repo files as they were before a pull |
| `~/.local/state/dotfiles/profile` | The profile chosen with `profile NAME` |

## Environment variables

| Variable | Meaning |
|---|---|
| `DOTFILES_NIX_HOST` | Flake host for `rebuild` (default `benjy`). |
| `DOTFILES_PROFILE` | Force a profile (or `none`/`auto`) for one run. |
| `DOTFILES_HOST` | Hostname used for `.dotfiles-hosts`. |
| `DOTFILES_BACKUP_DIR` | Backup location. |
| `XDG_CONFIG_HOME` | Target instead of `~/.config`. |
| `XDG_STATE_HOME` | State and backups instead of `~/.local/state`. |
| `NO_COLOR` | Disable colors. |

## Requirements

`bash`, `git`, `gum` and `fzf` (menu), `nvim` (merge), `inotify-tools` and
`notify-send` (watch), `wl-copy` or `xclip` (nvim clipboard; checked by `doctor`).

## Recipes

- **Save a tweak I made in ~/.config:** `pull --commit`, then `git push`.
- **Set up a new machine:** `git clone`, `./dotfiles.bash push -n`, then `push`.
- **First time on a new OS:** `profile new <os> <folders>`, edit, `push`.
- **Skip a file Omarchy rewrites:** `select`, untick `omarchy/shell.json`.
- **Oops:** `undo --yes`, or `restore NAME/FILE`.

## Troubleshooting

- **"No profile for this machine":** no `profiles/<os>/` matches. Run
  `./dotfiles.bash profile` to see what exists, then `profile NAME` or `profile new NAME`.
- **Everything shows "newer in repo" or "not installed" on a new machine:** expected
  before the first `push`. Run `push -n` first to preview.
- **A file shows "changed on both sides":** open Sync and choose, or run
  `merge NAME FILE`. Run `fetch` to see all differences first.
- **A file keeps coming back as edited:** a tool rewrites it. Untick it in
  `select`, or pull the change if it should be kept.
- **The menu says gum or fzf is missing:** `sudo pacman -S gum fzf`, or use the
  commands directly.
- **Something looks wrong after a push:** `undo --yes`, or `restore NAME/FILE`.
- **Broken links or old backups:** `./dotfiles.bash doctor`, then `clean --yes`.
- **Hyprland errors after `setup`:** `hyprctl configerrors`; `uninstall` removes the hook.
