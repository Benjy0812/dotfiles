#!/bin/sh
# Apply fix 003 part 1: GitButler-matching GTK3 menu bar theme.
# Part 2 (no title bar) is in files/PKGBUILD; see README.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
dst="$HOME/.config/gtk-3.0/gtk.css"
install -d "$(dirname "$dst")"
# First run only: keep the user's own gtk.css so revert.sh can put it back.
[ -f "$dst" ] && [ ! -e "$dst.bak" ] && ! cmp -s "$here/files/gtk.css" "$dst" && cp -p "$dst" "$dst.bak"
cp "$here/files/gtk.css" "$dst"
echo "gtk.css installed; restart GitButler"
