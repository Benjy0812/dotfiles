#!/bin/sh
# Undo fix 002.
rm -f "$HOME/.icons/default/index.theme"
rmdir "$HOME/.icons/default" "$HOME/.icons" 2>/dev/null || true
[ -f "$HOME/.Xresources" ] && sed -i '/^Xcursor\./d' "$HOME/.Xresources"
echo "reverted; restart Steam"
