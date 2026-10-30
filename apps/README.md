# Apps

App configs. Each folder goes to `~/.config/<folder>/`: NixOS deploys some of
them ([../nix](../nix/README.md)); elsewhere copy the ones you want over.

| Folder | What | Details |
|---|---|---|
| `alacritty/`, `kitty/`, `foot/`, `ghostty/` | Terminals, set up alike (see below) | |
| `fish/` | Fish shell: aliases, abbreviations, helper functions | [fish/README.md](fish/README.md) |
| `nvim/` | Neovim: plugin-free `init.lua` for learning | [nvim/README.md](nvim/README.md) |
| `yazi/` | Yazi file manager | [yazi/README.md](yazi/README.md) |
| `zed/`, `.zed/` | Zed editor settings and the Glass theme | [zed/README.md](zed/README.md) |
| `git/` | Git aliases, sane defaults, `gh` as credential helper | |

## Terminals

All four share one setup, so switching terminals changes nothing you notice:

- JetBrainsMono Nerd Font at size 9 (`sudo pacman -S ttf-jetbrains-mono-nerd`),
  14px padding, steady block cursor
- `Shift+Insert` / `Ctrl+Insert` paste and copy
- `Shift+Enter` and `Alt+Shift+Enter` sent as CSI-u, so TUIs and tmux can
  tell them apart from plain `Enter`
- Colors from the current Omarchy theme, so `omarchy theme set` restyles them

Kitty is also 50% transparent; the blur behind it comes from the compositor.
Kitty is the MangoWM terminal (`Alt+Return`), and Omarchy's default terminal
is set in Omarchy itself.

Outside Omarchy the theme include points at a file that isn't there, so the
terminals fall back to their default colors.
