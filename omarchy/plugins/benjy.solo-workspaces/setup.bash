#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
SRC="$DIR"
ID="benjy.solo-workspaces"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$ID"
# No binds or bar widget, so it hooks into autostart.lua.
HOOK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/autostart.lua"
# User settings, outside the plugin dir so reinstalls and uninstalls keep them.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/solo-workspaces.lua"

BEGIN="-- >>> $ID >>>"
END="-- <<< $ID <<<"

remove_hook() {
  [[ -f "$HOOK_FILE" ]] || return 0

  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip
  ' "$HOOK_FILE" > "$HOOK_FILE.tmp"

  mv "$HOOK_FILE.tmp" "$HOOK_FILE"
}

case "${1:-install}" in
  install)
    [[ -f "$HOOK_FILE" ]] || {
      echo "Missing $HOOK_FILE" >&2
      exit 1
    }

    cp "$HOOK_FILE" "$HOOK_FILE.bak"
    remove_hook

    # Skip the copy when run from the installed plugin dir itself.
    if [[ "$SRC" != "$(realpath -m "$DEST")" ]]; then
      mkdir -p "$DEST"
      cp "$SRC/manifest.json" "$SRC/solo-workspaces.lua" "$SRC/config.default.lua" "$SRC/LICENSE" "$SRC/README.md" "$DEST/"
    fi

    if [[ ! -f "$CONFIG" ]]; then
      cp "$SRC/config.default.lua" "$CONFIG"
      echo "Created $CONFIG"
    fi

    printf '%s\n' \
      "$BEGIN" \
      "dofile(\"$DEST/solo-workspaces.lua\")" \
      "$END" >> "$HOOK_FILE"

    hyprctl reload >/dev/null && hyprctl configerrors
    echo "Installed to $DEST"
    ;;

  uninstall)
    cp "$HOOK_FILE" "$HOOK_FILE.bak"
    remove_hook
    rm -rf "$DEST"
    hyprctl reload >/dev/null
    echo "Uninstalled. Settings kept in $CONFIG"
    ;;

  *)
    echo "Usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
