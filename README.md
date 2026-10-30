# Dotfiles

Personal Linux desktop configs, kept at `~/Projects/dotfiles`. Each folder has
its own README with the details.

| Folder | What | Details |
|---|---|---|
| `mango/` | MangoWM compositor with Noctalia: keys, monitors, look | [mango/README.md](mango/README.md) |
| `omarchy/` | Personal Omarchy (Hyprland) changes and two workspace plugins | [omarchy/README.md](omarchy/README.md) |
| `apps/` | App configs: terminals, fish, yazi, zed, git | [apps/README.md](apps/README.md) |
| `nix/`, `flake.nix` | NixOS system and home-manager profile | [nix/README.md](nix/README.md) |
| `fixes/` | Local patches for upstream bugs | [fixes/README.md](fixes/README.md) |

The Omarchy plugins have their own READMEs too:
[monitor-workspaces](omarchy/plugins/benjy.monitor-workspaces/README.md) and
[solo-workspaces](omarchy/plugins/benjy.solo-workspaces/README.md).

## Setup

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
```

Then put the configs in place, depending on the machine. On any machine,
`./dotfiles.bash` compares the repo with `~/.config` and syncs them (menu needs
`gum` and `fzf`). Or by hand:

- **NixOS:** `sudo nixos-rebuild switch --flake ~/Projects/dotfiles#benjy`
  deploys them through home-manager ([nix](nix/README.md)).
- **Omarchy:** `~/Projects/dotfiles/omarchy/install.bash`
  ([omarchy](omarchy/README.md)).
- **Anywhere else:** copy the folders you want from `apps/` (and `mango/`) into `~/.config/`, after
  backing up what's there.

## dotfiles.bash

`./dotfiles.bash help` lists everything. The main parts:

- **Menu:** the status table, then Sync, Backups, Tools. Sync is one fzf list of
  every file that differs, labeled `→ push`, `← pull` or `⚠ both`; `Tab` selects,
  `Enter` applies each file in the direction shown (conflicts ask first),
  `Ctrl-e` opens `nvim -d`. Backups restores (type a folder or file name to
  filter) or deletes old ones. Tools has Doctor, baseline and the Omarchy uninstall.
- **Push / pull:** `push [name|name/file]` copies repo to `~/.config`; `pull`
  copies edits back (`--commit` commits them, the menu offers commit and push).
  `-n` is a dry run everywhere.
- **Conflicts:** after `baseline` (or the first push or pull of a file) the
  script knows each file's last synced content, so it can tell "edited in
  `~/.config`" from "changed on both sides". Without that it goes by file time.
- **Backups:** a replaced file is moved to its own folder,
  `~/.local/state/dotfiles/backups/<folder>/<file>/<time>` (`DOTFILES_BACKUP_DIR`
  changes it), so a file with ten backups has one folder, not ten files beside it.
  `backups` lists them, `restore name/file` brings one back, `clean --yes`
  deletes the ones older than 30 days.
- **watch:** `./dotfiles.bash watch [--auto]` notifies when a tracked file is
  saved in `~/.config` (`--auto` pulls it). Run it at login, for example from
  Hyprland's `exec-once`. Needs `inotify-tools`.
- **doctor:** checks tools, that `.gitignore` does not hide tracked files, old
  backups and broken links.
- **Config files:** `.dotfilesignore` lists paths to skip; `.dotfiles-hosts`
  maps a hostname to the folders it should get (both optional). Fish
  completions live in `apps/fish/completions/dotfiles.bash.fish`.

## What's not tracked

`.gitignore` is a whitelist (`/*` plus explicit `!` entries), so anything not
listed stays out of git even when it's copied into the repo. That keeps out
private and machine-specific data such as `gh/` (GitHub credentials), browser
profiles, app state, generated Noctalia themes, and `apps/fish/fish_variables`.
Add a new folder to the whitelist before committing it.
