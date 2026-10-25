#!/bin/sh
# Verify fix 001: capture a live stream for a few seconds and report whether
# frames keep flowing (PASS) or the portal dies and the stream freezes (FAIL).
#
# Usage: ./run.sh [seconds]     (default 15; the old bug killed it at ~5s)
set -e
cd "$(dirname "$0")"

SECS="${1:-15}"

ELECTRON=""
for candidate in /usr/lib/electron*/electron; do
    [ -x "$candidate" ] && ELECTRON="$candidate"
done
if [ -z "$ELECTRON" ]; then
    ELECTRON="$(command -v electron || true)"
fi
if [ -z "$ELECTRON" ]; then
    echo "No electron binary found (looked in /usr/lib/electron*/electron)" >&2
    exit 1
fi

echo "electron:  $ELECTRON"
echo "duration:  ${SECS}s"
echo "portal:    $(systemctl --user is-active xdg-desktop-portal-wlr 2>/dev/null || echo unknown)"
echo

CAPTURE_TEST_SECONDS="$SECS" "$ELECTRON" main.js 2>/dev/null \
    | grep -E 'sources:|result:|VERDICT:'

echo
echo "--- portal errors in the last ${SECS}s (should be empty) ---"
journalctl --user -u xdg-desktop-portal-wlr --since "-${SECS}s" --no-pager -o cat 2>/dev/null \
    | grep -iE 'invalid buffer damage|protocol error|main process exited' || echo "(none)"
