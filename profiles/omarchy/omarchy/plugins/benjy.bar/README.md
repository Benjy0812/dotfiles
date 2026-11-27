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

| File               | What                                                            |
| ------------------ | --------------------------------------------------------------- |
| `AutoHide.qml`     | Peek logic: Super shortcuts, cursor polling, workspace flash    |
| `AutoHideModel.js` | Pure show/hide decisions; `node test_autohide.js` tests them    |
| `bar.lua`          | Super hold bind, loaded from `hypr/custom.lua`                  |
| `Bar.qml`          | Omarchy's bar with the `benjy` edits (`barOff`/`barPeek`/`peekScreen`) |

## After an Omarchy update

The clone does not follow Omarchy's bar. To pick up a newer bar, diff
`Bar.qml` against `/usr/share/omarchy/shell/plugins/bar/Bar.qml`, copy the new
one over, and reapply the lines marked `benjy` (`barHidden` split into
`barOff`/`barPeek`/`peekScreen`, the `AutoHide {}` line, the probe writing
`barOff`, `exclusionMode` on `barOff`, and the `parked` margins).
