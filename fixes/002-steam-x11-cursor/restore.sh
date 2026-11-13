#!/bin/sh
# Apply fix 002: make X11/Xwayland apps (Steam) use your cursor theme.
# Usage: ./restore.sh [THEME] [SIZE]   e.g. ./restore.sh Bibata-Modern-Ice 32
# Or edit the two defaults below. THEME = a folder name in /usr/share/icons or ~/.icons.
set -e
THEME="${1:-Bibata-Modern-Classic}"
SIZE="${2:-24}"

if [ ! -d "/usr/share/icons/$THEME/cursors" ] && [ ! -d "$HOME/.icons/$THEME/cursors" ] \
   && [ ! -d "$HOME/.local/share/icons/$THEME/cursors" ]; then
    echo "WARNING: cursor theme '$THEME' not found - install it first" >&2
fi

# Steam falls back to the "default" theme, which normally inherits Adwaita.
install -d "$HOME/.icons/default"
# First run only: keep the user's files so revert.sh can put them back.
[ -f "$HOME/.icons/default/index.theme" ] && [ ! -e "$HOME/.icons/default/index.theme.bak" ] \
    && cp -p "$HOME/.icons/default/index.theme" "$HOME/.icons/default/index.theme.bak"
printf '[Icon Theme]\nInherits=%s\n' "$THEME" > "$HOME/.icons/default/index.theme"

# Fallback for X11 apps that read Xresources; keeps any other lines.
touch "$HOME/.Xresources"
[ -e "$HOME/.Xresources.xcursor.bak" ] \
    || grep '^Xcursor\.' "$HOME/.Xresources" > "$HOME/.Xresources.xcursor.bak" || true
grep -v '^Xcursor\.' "$HOME/.Xresources" > "$HOME/.Xresources.tmp" || true
printf 'Xcursor.theme: %s\nXcursor.size: %s\n' "$THEME" "$SIZE" >> "$HOME/.Xresources.tmp"
# cat, not mv: keeps ~/.Xresources a symlink if it is one.
cat "$HOME/.Xresources.tmp" > "$HOME/.Xresources"; rm -f "$HOME/.Xresources.tmp"
command -v xrdb >/dev/null && xrdb -merge "$HOME/.Xresources" || true

echo "cursor: $THEME ($SIZE)"
echo "Also keep XCURSOR_THEME/XCURSOR_SIZE set in your compositor config."
echo "Fully quit Steam (steam -shutdown) and start it again."
