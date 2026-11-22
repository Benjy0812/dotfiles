#!/bin/sh
# Check fix 003 is still in place.
here="$(cd "$(dirname "$0")/.." && pwd)"
ok=0
cmp -s "$here/files/gtk.css" "$HOME/.config/gtk-3.0/gtk.css" && echo "ok: gtk.css installed" || { echo "FAIL: gtk.css missing or changed"; ok=1; }
grep -q 'decorations(false)' "$here/files/PKGBUILD" && echo "ok: PKGBUILD has title-bar patch" || { echo "FAIL: PKGBUILD lacks title-bar patch"; ok=1; }
pacman -Q gitbutler 2>/dev/null || echo "note: gitbutler package not installed"
exit $ok
