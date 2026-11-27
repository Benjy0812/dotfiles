# Dotfiles

Personal Linux desktop configs, kept at `~/Projects/dotfiles`. Each folder has
its own README with the details.

| Folder           | What                                                                                                      | Details                                                      |
| ---------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `profiles/<os>/` | What is linked on a machine: one folder per OS (omarchy, nixos, ubuntu...), each with its own app configs | [profiles/omarchy/README.md](profiles/omarchy/README.md)     |
| `common/`        | App configs every profile links; a profile file with the same path replaces the shared one                | [common/README.md](common/README.md)                         |
| `flake.nix`      | NixOS flake; its system and home-manager files are in `profiles/nixos/nix/`                               | [profiles/nixos/nix/README.md](profiles/nixos/nix/README.md) |
| `docs/`          | Guides, starting with [the dotfiles.bash usage](docs/usage.md)                                            | [docs/README.md](docs/README.md)                             |
| `fixes/`         | Local patches for upstream bugs                                                                           | [fixes/README.md](fixes/README.md)                           |

Machine snapshots (`machines/<host>/`) are backups, never linked.

## Setup

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles && ./dotfiles.bash bootstrap
```

`bootstrap` installs the profile's `packages.txt`, links `common/` and the
profile into `~/.config` with [GNU stow](https://www.gnu.org/software/stow/),
runs the Omarchy `setup`, then `doctor`. On NixOS it runs `rebuild` instead
([nix](profiles/nixos/nix/README.md)). A machine that already has configs: run
`./dotfiles.bash adopt` first and review `git diff`.

## dotfiles.bash

Each file of `common/` and the active profile (`profiles/<os>/`) becomes a link
in `~/.config`; a profile file replaces the `common/` file with the same path.
The live file is the repo file, so an edit in `~/.config` is a change in this
repo. Folders in `~/.config` stay real folders, so files you do not track stay
untouched.

| Command                  | What it does                                                         |
| ------------------------ | -------------------------------------------------------------------- |
| `bootstrap`              | New machine: packages, `link`, `setup`, `doctor`                     |
| `link [-n]`              | Link `common/` and the profile (`-n`: dry run)                       |
| `adopt`                  | First run: move existing `~/.config` files into the repo, then link  |
| `unlink`                 | Remove the links                                                     |
| `track PATH..`           | Move a `~/.config` file into the profile and link it back            |
| `doctor`                 | Broken links, unlinked repo files, link conflicts                    |
| `snapshot`               | Back up per-machine files (`shell.json`...) to `machines/<host>/`    |
| `setup`, `uninstall`     | Omarchy: add or remove the Hyprland hook; `setup` builds `benjy.bar` |
| `bar-update`, `bar-save` | Omarchy: rebuild `benjy.bar` from stock + `bar.patch`, or save edits |
| `rebuild [-n]`           | NixOS: rebuild from this repo's flake                                |
| `profile [NAME\|auto]`   | Show or set this machine's profile                                   |

Full guide: [docs/usage.md](docs/usage.md). Tests: `./tests.bash` (CI runs it too).

## What's not tracked

`.gitignore` is a whitelist (`/*` plus explicit `!` entries), so anything not
listed stays out of git even when it's copied into the repo. That keeps out
private and machine-specific data such as `gh/` (GitHub credentials), browser
profiles, app state, generated Noctalia themes, and `fish_variables`.
Add a new folder to the whitelist before committing it.
