# Solo Workspaces

Give chosen apps a workspace to themselves on [Omarchy](https://omarchy.org)
(Hyprland Lua config, 0.55+).

When a listed app opens on a workspace that already has other windows, it
moves to the nearest empty workspace on the same monitor. With 1, 3 and 4 in
use and Discord opening on 3, it goes to 2; ties go to the lower number. A
second window of the same app joins the first one's workspace instead.

Other windows opened onto a solo app's workspace are moved off the same way.

The same goes for windows you move: moving a window onto a solo app's
workspace, or the app onto a busy one, sends it to the nearest empty one.
Floating windows (dialogs, popups, pickers) are never moved and never count.

## Configure

Don't edit the plugin files; reinstalling overwrites them. `setup.bash` creates
your own settings file at `~/.config/hypr/solo-workspaces.lua` the first time,
from `config.default.lua`, and never touches it again (uninstall keeps it too):

```lua
return {
  apps = { "vesktop", "steam" },  -- classes from `hyprctl clients`
  push_others = true,             -- also move other windows off their workspace
  follow = true,                  -- go along to where the window lands
  slots = 10,                     -- search workspaces 1..10
}
```

Changes apply on their own within 2 seconds of saving. If an edit breaks the
file you get a notification and the last working settings stay active.

## With monitor-workspaces

Works on its own with plain workspaces 1-10. If
[benjy.monitor-workspaces](../benjy.monitor-workspaces) is installed too,
"nearest empty" is searched in that monitor's own 1-10.

## Install

```sh
./setup.bash            # install and hook into hypr/autostart.lua
./setup.bash uninstall
```

Run it again after updating the plugin, and after `omarchy refresh hyprland`.

## License

MIT, see [LICENSE](LICENSE).
