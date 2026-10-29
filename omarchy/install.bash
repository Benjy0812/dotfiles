#!/usr/bin/env bash
# Set up this repo's Omarchy changes: load hypr/custom.lua from
# ~/.config/hypr/hyprland.lua, link the plugin settings and install the
# plugins. Safe to run again, e.g. after `omarchy refresh hyprland`.
#
#   ./install.bash             # everything
#   ./install.bash uninstall   # undo everything
set -euo pipefail

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HYPRLAND="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
CUSTOM="dofile(\"$DIR/hypr/custom.lua\")"
PLUGINS=(benjy.monitor-workspaces benjy.solo-workspaces)
# Plugin settings tracked here, linked into ~/.config/hypr.
SETTINGS=(monitor-workspaces.lua solo-workspaces.lua)
HYPR_DIR="$(dirname "$HYPRLAND")"

[[ -f "$HYPRLAND" ]] || {
  echo "Missing $HYPRLAND" >&2
  exit 1
}

case "${1:-install}" in
  install)
    cp "$HYPRLAND" "$HYPRLAND.bak"
    # Skip Omarchy's preinstalled app binds; has to be set before its defaults load.
    sed -i 's/^-- *omarchy_preinstalled_bindings = false/omarchy_preinstalled_bindings = false/' "$HYPRLAND"
    # Load custom.lua last. Matches any earlier spelling of the line, too.
    grep -q 'omarchy/hypr/custom.lua' "$HYPRLAND" || echo "$CUSTOM" >> "$HYPRLAND"

    # Link before the plugin setups run, so they don't create default ones.
    for file in "${SETTINGS[@]}"; do
      target="$HYPR_DIR/$file"
      if [[ -e "$target" && ! -L "$target" ]]; then
        mv "$target" "$target.bak"
        echo "Moved your old $target to $target.bak"
      fi
      ln -sfn "$DIR/hypr/$file" "$target"
    done

    for plugin in "${PLUGINS[@]}"; do
      "$DIR/plugins/$plugin/setup.bash"
    done
    ;;

  uninstall)
    for plugin in "${PLUGINS[@]}"; do
      "$DIR/plugins/$plugin/setup.bash" uninstall
    done

    # Only remove links pointing here; the settings stay in this repo.
    for file in "${SETTINGS[@]}"; do
      target="$HYPR_DIR/$file"
      if [[ "$(readlink "$target" 2>/dev/null)" == "$DIR/hypr/$file" ]]; then
        rm "$target"
      fi
    done

    cp "$HYPRLAND" "$HYPRLAND.bak"
    sed -i '/omarchy\/hypr\/custom.lua/d' "$HYPRLAND"
    sed -i 's/^omarchy_preinstalled_bindings = false/-- omarchy_preinstalled_bindings = false/' "$HYPRLAND"
    hyprctl reload >/dev/null
    ;;

  *)
    echo "Usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
