#!/bin/sh
# Undo fix 003 part 1 (gtk.css). The title-bar patch lives in the PKGBUILD.
dst="$HOME/.config/gtk-3.0/gtk.css"
if [ -f "$dst.bak" ]; then mv "$dst.bak" "$dst"; else rm -f "$dst"; fi
echo "reverted; restart GitButler"
