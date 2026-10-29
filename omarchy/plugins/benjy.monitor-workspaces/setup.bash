#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
SRC="$DIR"
ID="benjy.monitor-workspaces"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$ID"
BINDINGS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
# User settings, outside the plugin dir so reinstalls and uninstalls keep them.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitor-workspaces.lua"

BEGIN="-- >>> $ID >>>"
END="-- <<< $ID <<<"

remove_hook() {
  [[ -f "$BINDINGS" ]] || return 0

  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip
  ' "$BINDINGS" > "$BINDINGS.tmp"

  mv "$BINDINGS.tmp" "$BINDINGS"
}

case "${1:-install}" in
  install)
    [[ -f "$BINDINGS" ]] || {
      echo "Missing $BINDINGS" >&2
      exit 1
    }

    cp "$BINDINGS" "$BINDINGS.bak"
    remove_hook

    # Skip the copy when run from the installed plugin dir itself.
    if [[ "$SRC" != "$(realpath -m "$DEST")" ]]; then
      mkdir -p "$DEST"
      cp "$SRC/manifest.json" "$SRC/Widget.qml" "$SRC/monitor-workspaces.lua" "$SRC/config.default.lua" "$SRC/LICENSE" "$SRC/README.md" "$DEST/"
    fi

    if [[ ! -f "$CONFIG" ]]; then
      cp "$SRC/config.default.lua" "$CONFIG"
      echo "Created $CONFIG"
    fi

    printf '%s\n' \
      "$BEGIN" \
      "dofile(\"$DEST/monitor-workspaces.lua\")" \
      "$END" >> "$BINDINGS"

    # Swap Omarchy's global workspace strip for this per-monitor one.
    if [[ -f "$SHELL_JSON" ]] && grep -q '"omarchy.workspaces"' "$SHELL_JSON"; then
      cp "$SHELL_JSON" "$SHELL_JSON.bak"
      sed -i "s/\"omarchy.workspaces\"/\"$ID\"/" "$SHELL_JSON"
    fi

    hyprctl reload >/dev/null && hyprctl configerrors
    # Plugin hot-reload can keep the old widget cached, so restart the bar.
    omarchy restart shell >/dev/null 2>&1 || true
    echo "Installed to $DEST"
    ;;

  uninstall)
    cp "$BINDINGS" "$BINDINGS.bak"
    remove_hook
    rm -rf "$DEST"
    if [[ -f "$SHELL_JSON" ]]; then
      sed -i "s/\"$ID\"/\"omarchy.workspaces\"/" "$SHELL_JSON"
    fi
    hyprctl reload >/dev/null
    omarchy restart shell >/dev/null 2>&1 || true
    echo "Uninstalled. Settings kept in $CONFIG"
    ;;

  *)
    echo "Usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
