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
- **Omarchy:** `./dotfiles.bash push`, then `./dotfiles.bash setup`
  ([omarchy](omarchy/README.md)).
- **Anywhere else:** `./dotfiles.bash push` copies the folders into `~/.config/` and keeps
  what it replaces as backups (`-n` shows what it would do first).

## dotfiles.bash

`./dotfiles.bash help` lists everything. The main parts:

- **Menu:** the status table and a "Next:" line, then Sync, Backups, Tools (and
  Undo last sync once something has been applied). Sync is one fzf list of every
  file that differs, labeled `→ save to ~/.config`, `← save to repo` or
  `⚠ both changed`. Safe files start ticked, so `Enter` is the usual answer;
  `Tab` toggles, `Ctrl-e` opens `nvim -d`. A review screen lists what will be
  replaced before anything is applied. Conflicts start unticked and ask: keep
  the repo copy, keep the ~/.config copy, merge in nvim, or skip.
- **Undo:** every push, pull and restore is logged. `undo --yes` (or Undo last sync
  in the menu) puts back the replaced ~/.config files, removes files the run
  created and restores repo files a pull overwrote. Undoing is itself undoable.
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
- **What syncs:** everything under `apps/`, `mango/` and `omarchy/` except
  `README.md`, `fish_variables` and `omarchy/hypr/custom.lua`. To change that, open the menu's
  "Choose what syncs" (or run `./dotfiles.bash select`), tick the files you want
  and press Enter; unticked files are skipped. It saves them to `.dotfilesignore`.
  `./dotfiles.bash setup` adds what copying cannot do for `omarchy/` (the hyprland.lua
  hook, the settings links, the plugin hooks); `uninstall` undoes it.
- **Profiles:** `profiles/<name>/<folder>/` replaces the shared `<folder>` (the one in
  `apps/`) on machines using that profile, so you keep one general setup and only
  override what differs: `profiles/omarchy/hypr/`, `profiles/nixos/git/`,
  `profiles/ubuntu/...`. A profile folder with a new name is simply added. The
  profile is detected (Omarchy, NixOS, then the distro name from `/etc/os-release`)
  and can be set with `./dotfiles.bash profile NAME` (or `auto`, `none`) or in
  Tools > Profile. Other profiles' folders are never touched.
- **Where files go:** each folder goes to `~/.config/<folder>/` unless `.dotfiles-map`
  says otherwise. One rule per line, `folder/path = target`; the longest match wins.
  A top-level repo folder named there (for example `extra = ~/somewhere`) becomes a
  folder of its own. `./dotfiles.bash map` shows the result.
- **Config files:** `.dotfilesignore` (local, not committed) lists paths to skip; `.dotfiles-hosts`
  maps a hostname to the folders it should get (both optional). Fish
  completions live in `apps/fish/completions/dotfiles.bash.fish`.

## What's not tracked

`.gitignore` is a whitelist (`/*` plus explicit `!` entries), so anything not
listed stays out of git even when it's copied into the repo. That keeps out
private and machine-specific data such as `gh/` (GitHub credentials), browser
profiles, app state, generated Noctalia themes, and `apps/fish/fish_variables`.
Add a new folder to the whitelist before committing it.
