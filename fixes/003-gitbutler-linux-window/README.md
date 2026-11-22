# 003 — GitButler: ugly GTK menu bar and a huge title bar

**Status:** applied (menu theme verified by eye; title-bar patch in the PKGBUILD)
**Date:** 2026-11-22
**Affects:** GitButler 0.23.5 built from `files/PKGBUILD`, Hyprland (Omarchy)

## Symptom

- The File / Project / Help menu bar is a plain GTK3 menu bar that doesn't
  match GitButler's dark UI.
- GTK draws its own big title bar on top, which is pointless under Hyprland.

## Root cause

GitButler adds a native menu on Linux (`crates/gitbutler-tauri/src/main.rs`,
`.menu(menu::build)`) and its Linux window (`src/window.rs`, the
`#[cfg(not(target_os = "macos"))] create()`) keeps the default decorations,
so GTK draws client-side title bars on Wayland.

## Fix

1. **Menu bar theme** — `files/gtk.css` → `~/.config/gtk-3.0/gtk.css`.
   Colors come from GitButler's dark tokens (`--clr-gray-*`, `--clr-pop-40`).
   Affects every GTK3 menu bar, not just GitButler. Restart GitButler to apply.
2. **No title bar** — `files/PKGBUILD` `prepare()` seds `.decorations(false)`
   into the Linux `create()` and fails the build if that didn't apply.
   Needs a rebuild: `cp files/PKGBUILD ~/gitbutler-pkg/ && cd ~/gitbutler-pkg && makepkg -sif`.

The PKGBUILD also carries two update-related changes vs. the old 0.21.2 one:
plain `nodejs` (Node ≥24 needed) and bundled libgit2 (0.23's git2-rs fork wants
`libgit2-experimental`, which Arch doesn't ship), so `LIBGIT2_NO_VENDOR` and
the `libgit2` dependency are gone.

Related, already in `profiles/omarchy/hypr/custom.lua`: GitButler opens
floating and centered (1160×720).

## Updating to a new GitButler version

Bump `pkgver`, update `sha256sums` (`makepkg -g`), rebuild. If the build stops
right after the `sed` in `prepare()`, upstream changed `window.rs` — check
whether it still needs patching.

## Check / undo

- `verify/check.sh`
- `revert.sh` removes the gtk.css (restores yours if you had one). For the
  title bar, drop the sed + grep lines from `prepare()` and rebuild.
