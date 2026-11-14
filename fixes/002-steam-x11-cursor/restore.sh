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
printf '[Icon Theme]\nInherits=%s\n' "$THEME" > "$HOME/.icons/default/index.theme"

# Fallback for X11 apps that read Xresources; keeps any other lines.
touch "$HOME/.Xresources"
grep -v '^Xcursor\.' "$HOME/.Xresources" > "$HOME/.Xresources.tmp" || true
printf 'Xcursor.theme: %s\nXcursor.size: %s\n' "$THEME" "$SIZE" >> "$HOME/.Xresources.tmp"
mv "$HOME/.Xresources.tmp" "$HOME/.Xresources"
command -v xrdb >/dev/null && xrdb -merge "$HOME/.Xresources" || true

echo "cursor: $THEME ($SIZE)"
echo "Also keep XCURSOR_THEME/XCURSOR_SIZE set in your compositor config."
echo "Fully quit Steam (steam -shutdown) and start it again."
