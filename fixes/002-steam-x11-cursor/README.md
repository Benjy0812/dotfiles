# 002 — Steam (X11) ignores the cursor theme

**Status:** applied and verified
**Date:** 2026-11-13
**Compositor:** Hyprland (Omarchy), Steam via Xwayland

## Symptom

Steam showed the default (Adwaita) cursor even though `XCURSOR_THEME` was set
correctly in its environment.

## Root cause

Steam resolves the cursor through the X11 `default` theme, not the env var.
`/usr/share/icons/default/index.theme` inherits `Adwaita`.

## Fix

`./restore.sh [THEME] [SIZE]` writes:

- `~/.icons/default/index.theme` with `Inherits=<THEME>` (this is the real fix)
- `~/.Xresources` `Xcursor.theme` / `Xcursor.size` (fallback)

To use another cursor, pass its name (a folder in `/usr/share/icons`), e.g.
`./restore.sh Bibata-Modern-Ice 32`, or edit the defaults at the top of the
script. Also change `XCURSOR_THEME` in `profiles/omarchy/hypr/custom.lua` so
Wayland apps match. Then fully quit Steam and start it again.

## Check / undo

- `verify/check.sh [THEME]`
- `revert.sh`
