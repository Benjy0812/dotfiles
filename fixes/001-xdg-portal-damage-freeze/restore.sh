#!/bin/sh
# Restore the config files that make fix 001 active.
# Use after a wipe of ~/.config, or when moving this fix to a fresh machine.
# Does NOT rebuild the patched binary - see
# ~/.local/src/xdg-desktop-portal-wlr-patched/rebuild.sh for that.
set -e
cd "$(dirname "$0")"

BIN="$HOME/.local/libexec/xdg-desktop-portal-wlr"
if [ ! -x "$BIN" ]; then
    echo "ERROR: patched binary missing: $BIN" >&2
    echo "       run ~/.local/src/xdg-desktop-portal-wlr-patched/rebuild.sh first" >&2
    exit 1
fi

# Keep the user's own portal config once, so revert.sh can put it back.
CONF="$HOME/.config/xdg-desktop-portal-wlr/config"
if [ -f "$CONF" ] && [ ! -e "$CONF.bak" ] && ! cmp -s "$CONF" files/xdg-desktop-portal-wlr.conf; then
    cp -p "$CONF" "$CONF.bak"
    echo "backed up: $CONF.bak"
fi

install -Dm644 files/override.conf \
    "$HOME/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf"
install -Dm644 files/xdg-desktop-portal-wlr.conf "$CONF"

systemctl --user daemon-reload
systemctl --user stop xdg-desktop-portal-wlr 2>/dev/null || true
systemctl --user restart xdg-desktop-portal

echo "restored:"
echo "  ~/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf"
echo "  ~/.config/xdg-desktop-portal-wlr/config"
echo "portal: $(systemctl --user is-active xdg-desktop-portal)"
