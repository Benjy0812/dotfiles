# Dotfiles

Personal Linux desktop configs, kept at `~/Projects/dotfiles`. Each folder has
its own README with the details.

| Folder | What | Details |
|---|---|---|
| `mango/` | MangoWM compositor with Noctalia: keys, monitors, look | [mango/README.md](mango/README.md) |
| `omarchy/` | Personal Omarchy (Hyprland) changes and two workspace plugins | [omarchy/README.md](omarchy/README.md) |
| `fish/` | Fish shell: aliases, abbreviations, helper functions | [fish/README.md](fish/README.md) |
| `kitty/` | Kitty terminal | [kitty/README.md](kitty/README.md) |
| `yazi/` | Yazi file manager | [yazi/README.md](yazi/README.md) |
| `zed/`, `.zed/` | Zed editor settings and the Glass theme | [zed/README.md](zed/README.md) |
| `nix/`, `flake.nix` | NixOS system and home-manager profile | [nix/README.md](nix/README.md) |
| `fixes/` | Local patches for upstream bugs | [fixes/README.md](fixes/README.md) |

The Omarchy plugins have their own READMEs too:
[monitor-workspaces](omarchy/plugins/benjy.monitor-workspaces/README.md) and
[solo-workspaces](omarchy/plugins/benjy.solo-workspaces/README.md).

## Setup

```bash
git clone https://github.com/Benjy0812/dotfiles.git ~/Projects/dotfiles
```

Then put the configs in place, depending on the machine:

- **NixOS:** `sudo nixos-rebuild switch --flake ~/Projects/dotfiles#benjy`
  deploys them through home-manager ([nix](nix/README.md)).
- **Omarchy:** `~/Projects/dotfiles/omarchy/install.bash`
  ([omarchy](omarchy/README.md)).
- **Anywhere else:** copy the folders you want into `~/.config/`, after
  backing up what's there.

## What's not tracked

`.gitignore` is a whitelist (`/*` plus explicit `!` entries), so anything not
listed stays out of git even when it's copied into the repo. That keeps out
private and machine-specific data such as `gh/` (GitHub credentials), browser
profiles, app state, generated Noctalia themes, and `fish/fish_variables`.
Add a new folder to the whitelist before committing it.
