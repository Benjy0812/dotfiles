# benjy.oled-idle

OLED care for [Omarchy](https://omarchy.org): Omarchy's idle service never blanks
the screens, so this shell service turns them off (DPMS) instead.

- After 3 min idle. Respects idle inhibitors (fullscreen video and games) and
  Omarchy's stay-awake toggle.
- 15 s after the last input while the lock screen is up, and again 15 s after
  Omarchy's auto-lock in case the lock screen woke the displays.

Mouse or keyboard input wakes them. No settings and no Hyprland-side code; it
loads as a `service` plugin listed in `~/.config/omarchy/shell.json`.
