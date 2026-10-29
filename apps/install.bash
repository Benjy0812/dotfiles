#!/usr/bin/env bash
# Copy every app config in this folder into ~/.config, keeping the layout:
# apps/kitty/kitty.conf -> ~/.config/kitty/kitty.conf. Folders are merged
# file by file, so other files already in ~/.config/<app>/ stay. Skipped:
# READMEs, this script, and fish_variables (fish's own runtime state).
#
#   ./install.bash      # copy everything
#   ./install.bash -n   # dry run: only show what would happen
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY=0
[[ "${1:-}" == "-n" ]] && DRY=1

# Copy one file to its target. -P keeps links (fish's br.fish) as links.
place() {
  local src="$1" dest="$2"
  local shown="${dest/#$HOME/\~}"

  if [[ -e "$dest" || -L "$dest" ]]; then
    # Links compare by where they point; following them breaks when the
    # target is missing (br.fish without broot installed).
    if [[ -L "$src" ]]; then
      [[ "$(readlink "$src")" == "$(readlink "$dest" 2>/dev/null)" ]] && return
    elif [[ ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
      return # already up to date
    fi
    # TODO(human): the target exists and differs from the repo copy.
  fi

  echo "copy    $shown"
  if ((!DRY)); then
    mkdir -p "$(dirname "$dest")"
    cp -P "$src" "$dest"
  fi
}

cd "$DIR"
# -mindepth 2 leaves out the files directly in apps/ (this script, README.md).
find . -mindepth 2 \( -type f -o -type l \) ! -name README.md ! -name fish_variables -print0 |
  while IFS= read -r -d '' file; do
    place "$DIR/${file#./}" "$CONFIG/${file#./}"
  done
