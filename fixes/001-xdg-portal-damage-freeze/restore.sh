#!/bin/sh
# Restore the config files that make fix 001 active.
# Use after a wipe of ~/.config, or when moving this fix to a fresh machine.
# Does NOT rebuild the patched binary - see
# ~/.local/src/xdg-desktop-portal-wlr-patched/rebuild.sh for that.
set -e
cd "$(dirname "$0")"

BIN="$HOME/.local/libexec/xdg-desktop-portal-wlr"
if [ ! -x "$BIN" ]; then
    echo "WARNING: patched binary missing: $BIN" >&2
    echo "         run ~/.local/src/xdg-desktop-portal-wlr-patched/rebuild.sh first" >&2
fi

install -Dm644 files/override.conf \
    "$HOME/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf"
install -Dm644 files/xdg-desktop-portal-wlr.conf \
    "$HOME/.config/xdg-desktop-portal-wlr/config"

systemctl --user daemon-reload
systemctl --user stop xdg-desktop-portal-wlr 2>/dev/null || true
systemctl --user restart xdg-desktop-portal

echo "restored:"
echo "  ~/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf"
echo "  ~/.config/xdg-desktop-portal-wlr/config"
echo "portal: $(systemctl --user is-active xdg-desktop-portal)"
