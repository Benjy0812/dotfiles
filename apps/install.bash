#!/usr/bin/env bash
# Copy every app config in this folder into ~/.config, keeping the layout:
# apps/kitty/kitty.conf -> ~/.config/kitty/kitty.conf. Folders are merged
# file by file, so other files already in ~/.config/<app>/ stay. A file that
# already exists and differs is moved to the backup folder first. It is
# ../dotfiles.bash push for every folder here, so backups, skips (READMEs,
# install scripts, fish_variables) and .dotfilesignore behave the same way.
#
#   ./install.bash      # copy everything
#   ./install.bash -n   # dry run: only show what would happen
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$DIR"

folders=()
for d in */ .[!.]*/; do
  [[ -d $d ]] && folders+=("${d%/}")
done

exec "$DIR/../dotfiles.bash" push "$@" "${folders[@]}"
