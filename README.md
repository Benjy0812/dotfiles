# Dotfiles

Personal Linux desktop configs, kept at `~/Projects/dotfiles`. Each folder has
its own README with the details.

| Folder            | What                                                                                                      | Details                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `profiles/<os>/`  | What is linked on a machine: one folder per OS (omarchy, nixos, ubuntu...), each with its own app configs | [profiles/omarchy/README.md](profiles/omarchy/README.md)     |
| `common/`         | App configs every profile links; a profile file with the same path replaces the shared one                | [common/README.md](common/README.md)                         |
| `flake.nix`       | NixOS flake; its system and home-manager files are in `profiles/nixos/nix/`                               | [profiles/nixos/nix/README.md](profiles/nixos/nix/README.md) |
| `docs/`           | Guides, starting with [the dotfiles.bash usage](docs/usage.md)                                            | [docs/README.md](docs/README.md)                             |
| `fixes/`          | Local patches for upstream bugs                                                                           | [fixes/README.md](fixes/README.md)                           |

The Omarchy plugin has its own README too:
[solo-workspaces](profiles/omarchy/omarchy/plugins/benjy.solo-workspaces/README.md).

## Setup

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
```

Then put the configs in place, depending on the machine. Needs GNU stow
(`sudo pacman -S stow`).

- **NixOS:** `./dotfiles.bash rebuild` (or `nixos-rebuild switch --flake ~/Projects/dotfiles#<host> --impure --sudo`)
  deploys them through home-manager ([nix](profiles/nixos/nix/README.md)).
- **Omarchy:** `./dotfiles.bash adopt` the first time (or `link` on a clean machine),
  then `./dotfiles.bash setup` ([omarchy](profiles/omarchy/README.md)).
- **Anywhere else:** `./dotfiles.bash link -n` to preview, then `link`.

## dotfiles.bash

`dotfiles.bash` links each file of the active profile (`profiles/<os>/`) into
`~/.config` with [GNU stow](https://www.gnu.org/software/stow/). The live file
is the repo file, so an edit in `~/.config` is a change in this repo: use git to
see it (`git diff`), save it (`git commit`), sync it (`git push`/`git pull`) and
undo it (`git restore`). Folders in `~/.config` stay real folders, so files you do
not track (like Omarchy's own files in `~/.config/hypr/`) stay untouched.
`README.md` files are never linked.

| Command                | What it does                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `link [-n]`            | Link the profile into `~/.config` (`-n`: dry run). Stow refuses to replace a real file.                                                                |
| `adopt`                | First run on a machine: move the existing `~/.config` files into the repo, then link them. Review with `git diff`; `git restore` what you do not want. |
| `unlink`               | Remove the links. The repo keeps the files.                                                                                                            |
| `track PATH..`         | Move a file from `~/.config` into the profile and link it back.                                                                                        |
| `setup`, `uninstall`   | Omarchy: add or remove the Hyprland hooks for `custom.lua` and the plugins.                                                                            |
| `rebuild [-n]`         | NixOS: rebuild from this repo's flake.                                                                                                                 |
| `profile [NAME\|auto]` | Show or set this machine's profile.                                                                                                                    |

Full guide: [docs/usage.md](docs/usage.md).

## What's not tracked

`.gitignore` is a whitelist (`/*` plus explicit `!` entries), so anything not
listed stays out of git even when it's copied into the repo. That keeps out
private and machine-specific data such as `gh/` (GitHub credentials), browser
profiles, app state, generated Noctalia themes, and `fish_variables`.
Add a new folder to the whitelist before committing it.
