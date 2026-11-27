# benjy.bar

Clone of Omarchy's `omarchy.bar` that auto-hides for OLED care. The bar overlays
windows while it peeks, so nothing resizes.

- **Auto-hide on/off:** `SUPER+SHIFT+SPACE` (`omarchy toggle bar`). The `bar-off`
  flag on means auto-hide; off means a normal, always-visible bar.
- **Peek:** hold Super, rest the cursor on the top edge, or switch workspace.
  It hides when Super is released, 1.5 s after the cursor leaves the bar, and
  never while a bar panel is open.
- **Settings** in `~/.config/omarchy/shell.json`:

  ```json
  "bar": { "autoHideMonitors": "focused" }
  ```

  `"focused"` (default) peeks only the focused monitor (hover: the one under
  the cursor); `"all"` peeks every monitor.

  ```json
  "bar": { "autoHideOverFullscreen": true }
  ```

  `true` (default) shows peeks over fullscreen windows; `false` keeps the bar
  under them and turns hover off there (Super still peeks, behind the window).

The repo keeps only our files and the edits to Omarchy's `Bar.qml`
(`bar.patch`). `./dotfiles.bash setup` (or `bar-update`) builds the rest from
the stock bar into `~/.config/omarchy/plugins/benjy.bar/` as real files.

| File               | What                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| `AutoHide.qml`     | Peek logic: Super shortcuts, cursor polling, workspace flash                  |
| `AutoHideModel.js` | Pure show/hide decisions; `node test_autohide.js` tests them                  |
| `bar.lua`          | Super hold bind, loaded from `hypr/custom.lua`                                |
| `bar.patch`        | The `benjy` edits to Omarchy's `Bar.qml` (`barOff`/`barPeek`/`peekScreen`)    |
| `manifest.json`    | Plugin id `benjy.bar`, cloned from `omarchy.bar`                              |

## After an Omarchy update

Run `./dotfiles.bash bar-update`. It copies the new stock bar and applies
`bar.patch`; if Omarchy changed the patched lines it stops and leaves the live
bar as it was. Then redo the lines marked `benjy` in the live `Bar.qml` on a
fresh copy of `/usr/share/omarchy/shell/plugins/bar/Bar.qml` and run
`./dotfiles.bash bar-save` to write the new `bar.patch`.

Editing the bar: change the live `Bar.qml`, then `bar-save`; `bar-update`
overwrites unsaved edits.
