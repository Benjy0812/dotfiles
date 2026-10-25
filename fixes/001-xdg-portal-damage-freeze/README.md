# 001 — Vesktop/Discord screen share freezes after ~5 seconds

**Status:** applied and verified
**Date:** 2026-10-25
**Compositor:** mango (wlroots/dwl-based), Wayland
**Client:** Vesktop 1.6.8 (Electron 43.8.3)

## Symptom

In Discord via Vesktop, starting a screen share works for roughly 5 seconds,
then the outgoing video freezes. Audio keeps working. Restarting the share
repeats the cycle.

## Root cause

`xdg-desktop-portal-wlr` **crashed** a few seconds into every screencast:

```
ext_image_copy_capture_frame_v1#23: error 2: Invalid buffer damage coordinates
wl_display_dispatch failed: Protocol error
xdg-desktop-portal-wlr.service: Main process exited, code=exited, status=1/FAILURE
```

mango reports frame damage in **output-layout coordinates** instead of
buffer-local coordinates. The primary monitor is positioned at `x=1920`
(`~/.config/mango/config.conf`), so a damage rect starts at x=1920 on a
1920-pixel-wide buffer → out of bounds → `ext-image-copy-capture` raises a
fatal protocol error → portal process dies → systemd restarts it → the
PipeWire stream stops → the viewer sees a frozen frame.

This is why it survives the first few seconds: the initial full frame is
valid, and the first *damaged region* is what kills it.

## Affected versions

| Component | Version at time of fix |
|---|---|
| `xdg-desktop-portal-wlr` | 0.8.4-1.1 (Arch/CachyOS) — **the buggy side** |
| `xdg-desktop-portal` | 1.22.1-2.1 |
| `mangowm` | 0.18.3-1.1 — sends layout-space damage |
| `vesktop-bin` | 1.6.8-1 |
| Electron | 43.8.3 |
| OS / kernel | CachyOS rolling / 7.3.0-5-cachyos |

Trigger condition: **the shared monitor must not be at layout position 0,0.**
Sharing a monitor at x=0,y=0 would not hit this particular crash.

## The fix

`damage-clamp.patch` — one hunk in `src/screencast/ext_image_copy.c`.

Before submitting damage to the compositor, every rect is validated against
the buffer bounds. If any rect falls outside, a single full-buffer damage rect
is reported instead. Damage is only an optimisation hint, so over-reporting is
always legal and the captured image is unchanged.

### Why not other approaches

| Alternative | Result |
|---|---|
| `xdg-desktop-portal-kde` / `-gnome` / `-hyprland` | Won't work: they require KWin / mutter / Hyprland. Screen sharing breaks completely on mango. |
| Force `wlr-screencopy` fallback instead of `ext-image-copy-capture` | Delivers exactly **1 frame** then stalls on mango. Dead end. |
| Move the monitor to x=0 | Works around it, but changes the desktop layout and only helps the monitor at the origin. |

## Where the fix lives

| Piece | Path |
|---|---|
| Patched binary (in use) | `~/.local/libexec/xdg-desktop-portal-wlr` |
| systemd drop-in that selects it | `~/.config/systemd/user/xdg-desktop-portal-wlr.service.d/override.conf` |
| Portal runtime config | `~/.config/xdg-desktop-portal-wlr/config` |
| Build tree + source | `~/.local/src/xdg-desktop-portal-wlr-patched/` |
| Snapshots of the two configs | `files/` in this folder |

The stock `/usr/lib/xdg-desktop-portal-wlr` is **untouched**; the drop-in
replaces only `ExecStart`, keeping the packaged unit, D-Bus activation and
`Restart=on-failure`.

Survives reboots and `pacman -Syu`. If `~/.local/libexec/` is lost, run
`~/.local/src/xdg-desktop-portal-wlr-patched/rebuild.sh`.

## Verify

```sh
./verify/run.sh
```

Opens a small animated window for ~15s and captures it through the same
Electron/PipeWire path Vesktop uses, then prints a verdict. Expected:

```
result: {"frames":~449,"lastFrameAt":~14995,"maxGapMs":~34,...}
VERDICT: FRAMES_FLOWING_FOR_15S
```

Also useful:

```sh
systemctl --user is-active xdg-desktop-portal-wlr
journalctl --user -u xdg-desktop-portal-wlr -n 20 --no-pager   # no "Invalid buffer damage"
```

Manual check: share a monitor in Vesktop and watch for more than 10 seconds.

## Restore configs (after a wipe)

```sh
./restore.sh
```

Copies `files/override.conf` and `files/xdg-desktop-portal-wlr.conf` back into
place and restarts the portal. Does **not** rebuild the binary — use
`rebuild.sh` for that.

## Revert

```sh
./revert.sh
```

Removes the systemd drop-in, restarts the portal, and returns you to the stock
package. **The ~5s freeze will come back** while sharing a monitor that is not
at layout position 0,0.

## Notes / possible upstream reports

- The damage-coordinate bug is compositor-side (mango), the fatal handling is
  portal-side. A proper upstream fix would be mango reporting buffer-local
  damage; the portal's hard crash on a bad hint is arguably also a bug.
- Window (per-app) capture is impossible on mango: it lacks
  `ext-foreign-toplevel-list-v1`. Only whole monitors can be shared.
- When mango fixes the damage coordinates, or `xdg-desktop-portal-wlr` starts
  clamping damage itself, this patch can be dropped.
