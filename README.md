# .config Setup

This repository contains personal configuration files for a lightweight Linux desktop environment setup. The configurations are tracked in git and can be cloned to set up a similar environment.

## 📋 Tracked Files

### Window Manager
- **`mango/`** - MangoWM (Wayland window manager) configuration
  - `config.conf` - Core window manager settings, keybindings, display layout, and appearance
  - `config.jsonc` - Waybar status bar configuration
  - `autostart.sh` - Startup script for wallpaper and background processes
  - `wall/1.png` - Desktop wallpaper
  - `style.css` - Waybar styling

### Terminal
- **`kitty/kitty.conf`** - Kitty terminal emulator configuration
  - Font: JetBrains Mono 12.5pt
  - Transparency and padding settings
  - Powerline-style tabs
  - Performance optimizations

### Code Editor
- **`zed/`** - Zed editor configuration
  - `settings.json` - Editor preferences and theme settings
  - `themes/Glass.json` - Custom Glass theme

## ⬇️ Required Dependencies

To use this configuration setup, you'll need to install the following tools:

### Core Requirements
- **[MangoWM](https://github.com/waycrate/MangoWM)** - Tiling Wayland window manager
- **[Kitty](https://sw.kovidgoyal.net/kitty/)** - GPU-based terminal emulator
- **[Zed](https://zed.dev)** - High-performance code editor
- **[Waybar](https://github.com/Alexays/Waybar)** - Status bar for Wayland
- **[Fuzzel](https://codeberg.org/dnkl/fuzzel)** - Application launcher



### Optional
- **[swaybg](https://github.com/swaywm/swaybg)** - Wayland wallpaper utility
- **[FZF](https://github.com/junegunn/fzf)** - Command-line fuzzy finder
- **[broot](https://github.com/Canop/broot)** - Fast tree-based file explorer
- **[btop](https://github.com/aristocratos/btop)** - Modern system monitor
- **[Fish Shell](https://fishshell.com/)** - User-friendly shell
- **[gh](https://github.com/cli/cli)** - GitHub CLI
- **[Jellyfin Desktop](https://jellyfin.org/)** - Media server client
- **[Spicetify](https://github.com/spicetify/spicetify-cli)** - Spotify client customization
- **[Vesktop](https://github.com/Vencord/Vesktop)** - Discord client with Vencord

## 🎨 Key Configuration Highlights

### MangoWM Keybindings
```
Terminal:           Alt + Return
Launcher (Fuzzel):  Alt + D
Workspaces:         Alt + 1/2/3
Window Focus:       Super + Arrow Keys
Fullscreen:         Super + f
Floating Toggle:    Super + v
Reload Config:      Super + r
```

### Display Setup
- **DP-2**: 1920x1080 @ 280Hz (Primary, x:0)
- **DP-3**: 1920x1080 @ 144Hz (Secondary, x:-1920)

### Appearance
- **Color Scheme**: One Dark Pro Glass theme in Zed
- **Blur Effect**: Enabled with optimized parameters
- **Font**: JetBrains Mono throughout
- **Cursor Theme**: Bibata-Modern-Classic (24px)
- **Border Radius**: 5px for rounded corners

## 📦 Installation Guide

1. **Install MangoWM and dependencies:**
   ```bash
   # Arch Linux
   sudo pacman -S kitty zed waybar fuzzel swaybg

   # Other distributions - refer to individual project installation guides
   ```

2. **Clone this config repository:**
   ```bash
   git clone https://github.com/Benjy0812/zed-hjson-extension.git ~/.config
   ```

3. **Set up Kitty font** (optional):
   ```bash
   # Install JetBrains Mono if not already installed
   mkdir -p ~/.local/share/fonts
   # Download and extract JetBrains Mono to ~/.local/share/fonts
   fc-cache -fv
   ```

4. **Start MangoWM:**
   - Log out and select MangoWM at your login screen, or
   - Run directly: `mango`

## 🔧 Manual/Ignored Configurations

The following tools have configurations in `.config` but are **not tracked** in this repository (listed in `.gitignore`). You may want to configure them according to your preferences:

- **broot** - File tree browser configuration
- **btop** - System resource monitor settings
- **fish** - Shell configuration
- **gh** - GitHub CLI configuration
- **github-copilot** - GitHub Copilot settings
- **jellyfin-desktop** - Jellyfin media server client
- **spicetify** - Spotify client customization
- **vesktop** - Discord client customization

## 🎯 Workflow

This setup is optimized for:
- **Tiling window management** on Wayland
- **Fast terminal workflows** with Kitty
- **Efficient code editing** with Zed
- **Quick application launching** with Fuzzel
- **Minimal resource usage** with a custom window manager

## 🤝 Contributing

These are personal configuration files. Feel free to adapt them to your own setup!

## 📝 Notes

- This configuration uses **Wayland**, not X11
- Some settings may need adjustment based on your hardware (e.g., display refresh rates)
- Theme and font choices can be customized in their respective config files
- The Glass theme for Zed provides a modern, translucent appearance

---

**Last Updated**: 2026-06-03
