# Fish

[Fish](https://fishshell.com/) shell config, used by the session and Kitty.

| File | What |
|---|---|
| `config.fish` | Sets `$SHELL` to fish, bun, and `PATH` (`~/.local/bin`, bun) |
| `conf.d/aliases.fish` | `l`, `ll`, `la`; colored `grep`; `cp`/`mv`/`rm` ask before overwriting |
| `conf.d/abbreviations.fish` | Expand as you type: git (`gs`, `ga`, `gc`, ...), folders (`home`, `conf`, `proj`), bun (`buni`, `bund`, `bunb`, ...) |
| `conf.d/theme.fish` | Syntax colors |
| `conf.d/omarchy.fish` | Omarchy's bash setup for fish: editor/browser, mise, starship, zoxide (`z`), fzf keys, eza `ls` |
| `conf.d/extract.fish` | `extract <file>`: unpack any archive format |
| `conf.d/mkcd.fish` | `mkcd <dir>`: make a directory and enter it |
| `conf.d/paru.fish` | `paru <query> <n>`: a trailing number limits the results |
| `functions/y.fish` | `y`: open Yazi and `cd` to where you quit it |
| `functions/br.fish` | `br`: [broot](https://dystroy.org/broot/) launcher; a link to the one broot installs, so it needs broot |
| `completions/bun.fish` | Bun completions |

`fish_variables` is rewritten by fish at runtime and not tracked.

## Setup

### 1. Install fish

Any way works, as long as `fish --version` prints 3.4 or newer afterwards:

| System | Command |
|---|---|
| Arch, Omarchy, CachyOS | `sudo pacman -S fish` |
| Debian, Ubuntu | `sudo apt install fish` |
| Fedora | `sudo dnf install fish` |
| NixOS | already done: `programs.fish.enable` in [`nix/`](../../nix/README.md) |
| macOS | `brew install fish` |
| Anything else | see [fishshell.com](https://fishshell.com/) |

### 2. Put this config in place

```bash
~/Projects/dotfiles/apps/install.bash -n   # see what it would copy
~/Projects/dotfiles/apps/install.bash      # copy all app configs, fish included
```

Or copy just fish: `cp -rP ~/Projects/dotfiles/apps/fish ~/.config/`. On NixOS,
`nixos-rebuild` deploys it for you.

### 3. Optional tools

None are required; each part of the config is skipped when its tool is
missing. Install the ones you want:

- **starship** (prompt), **zoxide** (`z`), **fzf** (`Ctrl+R` history search),
  **eza** (`ls` with icons), **mise** (node, bun, ... versions) - all set up
  by `conf.d/omarchy.fish`, and already there on Omarchy
- **yazi** for `y`, **broot** for `br`, **bun** for the bun abbreviations

### 4. Make fish your shell

```bash
which fish                   # its path, e.g. /usr/bin/fish
chsh -s "$(which fish)"      # asks for your password
```

Log out and back in, and new terminals open in fish. If `chsh` says the shell
isn't allowed, add that path to `/etc/shells` first:
`which fish | sudo tee -a /etc/shells`.

To only try it without switching, type `fish` in a terminal. Switch back any
time with `chsh -s "$(which bash)"`; scripts that start with `#!/bin/bash`
(like Omarchy's) keep working either way.
