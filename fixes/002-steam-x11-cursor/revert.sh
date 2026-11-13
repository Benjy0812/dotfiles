#!/bin/sh
# Undo fix 002.
if [ -f "$HOME/.icons/default/index.theme.bak" ]; then
    mv "$HOME/.icons/default/index.theme.bak" "$HOME/.icons/default/index.theme"
else
    rm -f "$HOME/.icons/default/index.theme"
    rmdir "$HOME/.icons/default" "$HOME/.icons" 2>/dev/null || true
fi
# Drop the fix's Xcursor lines, then append the ones restore.sh saved.
# cat, not mv/sed -i: keeps ~/.Xresources a symlink if it is one.
if [ -f "$HOME/.Xresources" ]; then
    grep -v '^Xcursor\.' "$HOME/.Xresources" > "$HOME/.Xresources.tmp" || true
    [ -f "$HOME/.Xresources.xcursor.bak" ] && cat "$HOME/.Xresources.xcursor.bak" >> "$HOME/.Xresources.tmp"
    cat "$HOME/.Xresources.tmp" > "$HOME/.Xresources"; rm -f "$HOME/.Xresources.tmp"
fi
rm -f "$HOME/.Xresources.xcursor.bak"
echo "reverted; restart Steam"
