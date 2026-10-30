# dotfiles.bash usage

`dotfiles.bash` compares the active profile in this repo with `~/.config` and
syncs the two. `./dotfiles.bash help` prints a short version of this page.

## Contents

- [Concepts](#concepts)
- [Quick start](#quick-start)
- [The menu](#the-menu)
- [Commands](#commands)
- [Options](#options)
- [Names](#names)
- [Profiles](#profiles)
- [Config files](#config-files)
- [Backups and undo](#backups-and-undo)
- [Omarchy](#omarchy)
- [Environment variables](#environment-variables)
- [Requirements](#requirements)
- [Recipes](#recipes)

## Concepts

- **Profile:** `profiles/<os>/` (omarchy, nixos, ubuntu...). Only the active
  profile is synced. `apps/` and `mango/` are boilerplate that `profile new` copies.
- **Folder:** each folder in the profile goes to `~/.config/<folder>/`
  (change with `.dotfiles-map`).
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

To add an OS: `./dotfiles.bash profile new ubuntu kitty git fish`, then edit
`profiles/ubuntu/`. The copy is independent of `apps/` and other profiles.

## Config files

All optional, in the repo root.

- **`.dotfilesignore`** (local, not committed): paths to skip, one glob per line
  (`folder/file`, `*` matches slashes, `#` comments). Edited by `select`.
  Always skipped: `*/README.md`, `*/fish_variables`, `hypr/custom.lua`.
- **`.dotfiles-map`**: `folder/path = target`, longest match wins, `~` is home.
  Default is `~/.config/<folder>/`.
  ```text
  kitty/themes = ~/.local/share/kitty-themes
  ```
- **`.dotfiles-hosts`**: `hostname: folder folder` limits which folders a machine
  gets; `*` or no line means all. Find the name with `uname -n`.

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

## Environment variables

| Variable | Meaning |
|---|---|
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
