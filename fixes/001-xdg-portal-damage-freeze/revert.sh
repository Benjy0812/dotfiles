#!/bin/sh
# Undo fix 001 and return to the stock xdg-desktop-portal-wlr package.
#
# NOTE: the original bug will return - screen sharing will freeze again after
# ~5 seconds when the shared monitor is not at layout position 0,0.
set -e

DROPIN="$HOME/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf"

if [ -f "$DROPIN" ]; then
    rm -f "$DROPIN"
    rmdir "$(dirname "$DROPIN")" 2>/dev/null || true
    echo "removed: $DROPIN"
else
    echo "drop-in already absent: $DROPIN"
fi

systemctl --user daemon-reload
systemctl --user stop xdg-desktop-portal-wlr 2>/dev/null || true
systemctl --user restart xdg-desktop-portal

echo
echo "portal now uses: $(systemctl --user show xdg-desktop-portal-wlr -p ExecStart --value 2>/dev/null || echo 'stock package')"
echo "patched binary left in place (unused): $HOME/.local/libexec/xdg-desktop-portal-wlr"
echo "source tree left in place:             $HOME/.local/src/xdg-desktop-portal-wlr-patched"
echo
echo "Fully restart Vesktop before testing. Expect the ~5s freeze to be back."
