#!/usr/bin/env bash
# Install this folder's init.lua as ~/.config/nvim/init.lua. An existing
# init.lua that differs (for example Omarchy's LazyVim one) is moved to the
# backup folder first. Other files in ~/.config/nvim/ stay untouched. It is
# ../../dotfiles.bash push nvim, plus a check for nvim and a clipboard tool.
#
#   ./install.bash      # install
#   ./install.bash -n   # dry run: only show what would happen
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

command -v nvim >/dev/null || echo "warning: nvim is not installed (sudo pacman -S neovim)" >&2

"$DIR/../../dotfiles.bash" push "$@" nvim

# clipboard = "unnamedplus" needs one of these to reach the system clipboard.
command -v wl-copy >/dev/null || command -v xclip >/dev/null ||
  echo "note: no clipboard tool found (sudo pacman -S wl-clipboard)" >&2
