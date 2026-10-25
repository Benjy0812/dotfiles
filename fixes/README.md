# System fixes

Documentation and restore material for fixes applied to this machine **outside
package management** — local patches, config overrides, workarounds for
upstream bugs.

Nothing in this folder is executed automatically. Each subfolder is
self-contained: its own README, the patch, snapshots of the live config files,
a verification script, and revert instructions.

## Index

| # | Fix | Affects | Status | Date |
|---|-----|---------|--------|------|
| 001 | [Vesktop/Discord screen share freezes after ~5s](001-xdg-portal-damage-freeze/README.md) | `xdg-desktop-portal-wlr` 0.8.4 + `mangowm` 0.18.3 | applied, verified | 2026-10-25 |

## Conventions

- One folder per fix, numbered `NNN-short-slug/`.
- `README.md` in each folder states the symptom, root cause, exact package
  versions affected, what was changed, and how to undo it.
- `files/` holds copies of the live config files that make the fix active.
  These are **snapshots**, not the live copies — the README says where each
  one actually lives.
- `verify/` holds a runnable check so you can confirm the fix still works after
  a reboot or a package upgrade.
- `revert.sh` undoes the fix.

## When a fix becomes obsolete

If a package update fixes the bug upstream, delete the override, run
`revert.sh`, and mark the folder `obsolete` in the table above (or delete the
folder). Prefer the distro package over a local patch whenever possible.
