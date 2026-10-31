# Nix

The flake (`../../../flake.nix`) has two outputs:

- **`nixosConfigurations.benjy`** - full NixOS system. No desktop environment:
  the ly TUI login manager starts MangoWM, and home-manager deploys the dotfiles.
- **`homeConfigurations.benjy`** - standalone home-manager profile for
  non-NixOS machines (e.g. CachyOS). Installs packages only and never touches
  `~/.config`.

The profile holds two kinds of things side by side:

```text
profiles/nixos/
  <app folders>/    kitty, fish, mango, ...  deployed into ~/.config (automatically)
  profile.conf      preferred terminal, editor, window manager (optional)
  nix/              the Nix side, below
```

| Path in `nix/` | What |
|---|---|
| `configuration.nix` | System: boot, ly login + MangoWM, fish, fonts, packages |
| `patches/` | Patches built into packages (screen-share fix for the wlr portal) |
| `hosts/<name>/` | One folder per machine: `default.nix` (hostname, swap). Each folder becomes `nixosConfigurations.<name>`. Hardware is read from the machine's own `/etc/nixos/hardware-configuration.nix`, so builds need `--impure` |
| `home.nix` | home-manager packages, shared by both outputs |
| `dotfiles.nix` | Deploys every folder of the profile into `~/.config` |
| `standalone.nix` | Extra settings for the standalone profile |

## Use

```bash
# Rebuild from the checked-out repo (same as ./dotfiles.bash rebuild)
nixos-rebuild switch --flake ~/Projects/dotfiles#<host> --impure --sudo

# New machine: install NixOS normally (that writes
# /etc/nixos/hardware-configuration.nix), boot it, then as your user:
nix-shell -p git --run 'git clone https://github.com/Benjy0812/dotfiles ~/Projects/dotfiles'
cd ~/Projects/dotfiles
cp -r profiles/nixos/nix/hosts/benjy profiles/nixos/nix/hosts/<name>   # only for another machine
$EDITOR profiles/nixos/nix/hosts/<name>/default.nix                   # hostname, swap file
git add -A   # a flake ignores untracked files
nixos-rebuild switch --flake .#<name> --impure --sudo \
  --extra-experimental-features 'nix-command flakes'   # until the first switch enables flakes

# Standalone profile on another distro (Nix must be installed)
nix run github:nix-community/home-manager -- switch --flake ~/Projects/dotfiles#benjy
```

A flake only sees files committed to git, so commit new configs before
rebuilding. Adding or removing an app means adding or removing its folder in
the profile; `dotfiles.nix` picks it up on the next rebuild.
