# .config Setup

This repository contains personal configuration files for a lightweight Linux desktop environment setup. The configurations are tracked in git and can be cloned to set up a similar environment.

## 📋 Tracked Files

### Window Manager
- **`mango/`** - MangoWM (Wayland window manager) configuration
  - `config.conf` - Core settings, environment, keybindings, display layout, and appearance
  - `conf.d/appearance.conf` - Cursor, borders, gaps, and blur
  - `conf.d/bind.conf` - Key and mouse bindings
  - `conf.d/rules.conf` - Window rules
  - `scripts/autostart.sh` - Startup script for Noctalia and the wallpaper
  - `wall/1.png` - Desktop wallpaper

### Omarchy
- **`omarchy/plugins/benjy.monitor-workspaces/`** - Independent workspaces 1-10 per monitor, plus a bar widget (see its README; install with `setup.bash`)

### Shell
- **`fish/`** - Fish shell configuration
  - `config.fish` - PATH, `$SHELL`, and bun setup
  - `conf.d/` - Aliases, abbreviations, theme, and helper functions
  - `functions/y.fish` - Yazi wrapper that changes the working directory

### Terminal
- **`kitty/kitty.conf`** - Kitty terminal emulator configuration
  - Font: JetBrains Mono 12pt
  - Shell: `/usr/bin/fish`
  - Transparency and padding settings
  - Performance optimizations

### Code Editor
- **`zed/`** - Zed editor configuration
  - `settings.json` - Editor preferences and theme settings
  - `keymap.json` - Custom keybindings
  - `themes/Glass.json` - Custom Glass theme

### File Manager
- **`yazi/yazi.toml`** - Yazi terminal file manager configuration

### NixOS / Nix
- **`flake.nix`** - Flake with two outputs:
  - `nixosConfigurations.benjy` - full NixOS system. Installs MangoWM, makes it the default SDDM session, and deploys these dotfiles automatically through home-manager.
  - `homeConfigurations.benjy` - standalone home-manager profile for non-NixOS machines. Installs packages only and never touches `~/.config`.
- **`nix/nixos/`** - system, home-manager, and dotfile-deployment modules.
- **`nix/nixos-wsl/`** - separate WSL configuration (not part of the flake).

Rebuild the NixOS system from this repo:
```bash
sudo nixos-rebuild switch --flake ~/.config#benjy
```

On a fresh NixOS install where the repo is not checked out yet:
```bash
sudo nixos-rebuild switch --flake github:Benjy0812/dotfiles#benjy
```

Use the standalone profile on a non-NixOS system (Nix must be installed):
```bash
nix run github:nix-community/home-manager -- switch --flake ~/.config#benjy
```

> **Repo layout:** the git repository root *is* `~/.config`. Files live there directly — there are no symlinks to a separate `~/dotfiles` directory.

## ⬇️ Required Dependencies

To use this configuration setup, you'll need to install the following tools:

### Core Requirements
- **[MangoWM](https://github.com/mangowm/mango)** - Tiling Wayland window manager
- **[Kitty](https://sw.kovidgoyal.net/kitty/)** - GPU-based terminal emulator
- **[Fish](https://fishshell.com/)** - Shell used by the session and Kitty
- **[Noctalia](https://noctalia.dev)** - Bar, launcher, notifications, and theme generation

### Optional
- **[Zed](https://zed.dev)** - High-performance code editor
- **[Yazi](https://yazi-rs.github.io/)** - Terminal file manager (`Alt + E`)
- **[Jellyfin Desktop](https://jellyfin.org/)** - Media server client
- **[Vesktop](https://github.com/Vencord/Vesktop)** - Discord client with Vencord

## 🎨 Key Configuration Highlights

### MangoWM Keybindings
```
Terminal:           Alt + Return
Launcher:           Alt + D          (Noctalia)
File manager:       Alt + E          (Yazi in Kitty)
Workspaces:         Alt + 1..9
Move to workspace:  Alt + Shift + 1..9
Window focus:       Alt + Arrow keys
Fullscreen:         Super + f
Reload config:      Super + r
Screenshot:         Super + Shift + s (Noctalia)
Close window:       Alt + q
Quit MangoWM:       Super + Shift + q
```

### Display Setup
- **AOC 2590G4**: 1920x1080 @ 144Hz (left, x:0, y:0)
- **AOC C27G4ZXU**: 1920x1080 @ 280Hz (right, primary, x:1920, y:0)
- **eDP-1** (laptop): 2880x1800 @ 1.5x scale (x:0, y:1080)

### Appearance
- **Cursor Theme**: Adwaita (24px)
- **Border**: 2px, 4px radius
- **Gaps**: 0px inner, 2px outer
- **Blur**: Enabled
- **Font**: JetBrains Mono throughout

## 📦 Installation Guide

1. **Install MangoWM and dependencies:**
   ```bash
   # Arch Linux
   sudo pacman -S kitty fish
   # Noctalia is available from the AUR
   paru -S noctalia
   ```

2. **Clone this repo into `~/.config`:**
   The repo root is `~/.config` itself, so there are no symlinks. Because `~/.config` always already exists, clone elsewhere and copy the tracked files in:
   ```bash
   git clone https://github.com/Benjy0812/dotfiles.git /tmp/dotfiles
   cp -a /tmp/dotfiles/. ~/.config/
   rm -rf /tmp/dotfiles
   ```
   `cp -a` also copies `.git`, making `~/.config` the repository. Back up any existing files it would overwrite first.

3. **Verify the repo:**
   ```bash
   cd ~/.config
   git status
   ```
   Only the whitelisted paths are tracked: `fish/`, `kitty/`, `mango/`, `nix/`, `yazi/`, `zed/`, `.zed/`, `README.md`, and `.gitignore`. Everything else in `~/.config` is ignored.

4. **Set up Kitty font** (optional):
   ```bash
   # Install JetBrains Mono if not already installed
   mkdir -p ~/.local/share/fonts
   # Download and extract JetBrains Mono to ~/.local/share/fonts
   fc-cache -fv
   ```

5. **Start MangoWM:**
   - Log out and select MangoWM at your login screen, or
   - Run directly: `mango`

## 🔧 Manual/Ignored Configurations

`.gitignore` uses a whitelist (`/*` plus explicit `!` entries), so anything in `~/.config` that is not listed above is untracked automatically. That includes private and machine-specific data such as:

- **`gh/`** - GitHub CLI credentials
- **`mozilla/`**, **`zen/`** - browser profiles
- **`vesktop/`** - Discord client data
- **`opencode/`** - OpenCode state
- **`noctalia/`** - generated Noctalia theme files
- **`btop/`**, **`dconf/`**, **`gtk-3.0/`**, **`pulse/`**, **`@liner/`**, **`autostart/`**
- **`mimeapps.list`**, **`user-dirs.dirs`**, **`user-dirs.locale`**

These should never be committed; the whitelist keeps them out.

## 🎯 Workflow

This setup is optimized for:
- **Tiling window management** on Wayland
- **Fast terminal workflows** with Kitty
- **Efficient code editing** with Zed
- **Quick application launching** with Noctalia
- **Minimal resource usage** with a custom window manager

## 🤝 Contributing

These are personal configuration files. Feel free to adapt them to your own setup!

## 📝 Notes

- This configuration uses **Wayland**, not X11
- Some settings may need adjustment based on your hardware (e.g., display refresh rates)
- Theme and font choices can be customized in their respective config files
- The Glass theme for Zed provides a modern, translucent appearance

---

**Last Updated**: 2026-10-25
