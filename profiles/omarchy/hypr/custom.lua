-- Personal Hyprland settings on top of Omarchy's defaults. The rest of
-- ~/.config/hypr stays stock; the only other Hyprland file tracked here is
-- solo-workspaces.lua (the plugin's settings).
--
-- Setup: ~/.config/hypr/hyprland.lua needs two changes, since this file is
-- loaded from there and runs after Omarchy's defaults.
--
-- 1. Before `require("default.hypr.omarchy")`, uncomment this so Omarchy's
--    preinstalled app/webapp binds are skipped (too late to set it here):
--      omarchy_preinstalled_bindings = false
--
-- 2. At the end of the file, load this one:
--      dofile(os.getenv("HOME") .. "/Projects/dotfiles/profiles/omarchy/hypr/custom.lua")
--
-- Then validate: hyprctl reload && hyprctl configerrors
-- `omarchy refresh hyprland` resets hyprland.lua, so redo both after it.

-- Apps menu: moved from SUPER+ALT+SPACE to SUPER+D
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + D", "Apps menu", "omarchy-menu toggle apps")

hl.config({
  input = {
    -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
    kb_layout = "no",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",

    -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",

    -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,

    -- Start with numlock on by default.
--     numlock_by_default = true,

    -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,

    -- Turn off mouse acceleration (default: adaptive).
    accel_profile = "flat",
  },
})

-- Cursor: Bibata Modern (AUR bibata-cursor-theme-bin). "Classic" is black,
-- "Ice" is white. Size stays at Omarchy's 24. GTK apps read the theme from
-- gsettings instead: gsettings set org.gnome.desktop.interface cursor-theme <name>
local cursor = "Bibata-Modern-Classic"
hl.env("XCURSOR_THEME", cursor)
hl.env("HYPRCURSOR_THEME", cursor)

-- Mesa (AMD/Intel) shader cache limit, raised so games like Counter-Strike
-- don't get their compiled shaders evicted. NVIDIA ignores this; its
-- equivalent is __GL_SHADER_DISK_CACHE_SIZE.
hl.env("MESA_SHADER_CACHE_MAX_SIZE", "50G")

-- https://wiki.hypr.land/configuring/core/config-options/#opacity
hl.window_rule({
    -- Which windows the rule applies to, matched by window class (".*" = all).
    match = { class = ".*" },
    -- Window opacity (0.0 = fully transparent, 1.0 = fully opaque).
    opacity = 1.0,
})

-- Monitors and HDR are per machine: hypr/hosts/<hostname>.lua, loaded at the end.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners.
    rounding = 0,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    dim_inactive = false,
    dim_strength = 0.1,

    -- Blur behind see-through windows (Kitty's background_opacity). Omarchy
    -- turns it off; same values as mango's appearance.conf on NixOS.
    blur = {
      enabled = true,
      size = 8,          -- strength; higher = blurrier
      passes = 3,        -- smoothness (1-4); more = smoother but heavier
      noise = 0.02,      -- grain, hides banding
      brightness = 0.9,  -- <1 darkens what's behind
      contrast = 0.9,
      vibrancy = 0.17,   -- boosts colors behind the window
      xray = false,      -- true = blur only the wallpaper, not windows behind
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,

     -- Change to niri-like side-scrolling layout.
     --layout = "scrolling",
  },
})

-- Star Citizen: allow tearing (like Windows exclusive fullscreen) for lower
-- input latency when in-game VSync is off.
hl.config({ general = { allow_tearing = true } })
hl.window_rule({ match = { class = "starcitizen.exe" }, immediate = true })

-- Flatpak apps (Bottles, GitButler) in the app launcher
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

-- GitButler: open floating and centered at its default size. Class is
-- gitbutler-tauri today; com.gitbutler.app if the GTK app ID takes over.
o.window("^(gitbutler-tauri|com\\.gitbutler\\.app)$", {
  float = true,
  center = true,
  size = { 1160, 720 },
})

-- Steam games: controller input doesn't reset Wayland idle, so keep the
-- screen on while a game is fullscreen (Omarchy only covers the Steam client).
-- Tile them too: floating breaks games, and a floating game reopens where it
-- last was, which can be off a monitor that has since been unplugged or moved.
o.window("^steam_app_.*$", { idle_inhibit = "fullscreen", tile = true })

-- GTK/XWayland scale; matches the monitors' scale 1 (Omarchy's stock default is 2).
hl.env("GDK_SCALE", "1")

-- Shell plugins with Hyprland-side code (moved here from hypr/autostart.lua).
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/benjy.solo-workspaces/solo-workspaces.lua")
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/benjy.workspaces/workspaces.lua")
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/benjy.bar/bar.lua")

-- Floating windows left off every monitor (one unplugged or moved, or an app
-- reopening where it last was) are centered on the monitor they belong to.
-- Run by hand with: hyprctl dispatch 'rescue_offscreen()'
local function onscreen(w)
  local cx, cy = w.at.x + w.size.x / 2, w.at.y + w.size.y / 2
  for _, m in ipairs(hl.get_monitors()) do
    local width, height = m.width / m.scale, m.height / m.scale
    if (m.transform or 0) % 2 == 1 then width, height = height, width end
    if cx >= m.x and cx < m.x + width and cy >= m.y and cy < m.y + height then return true end
  end
  return false
end
function rescue_offscreen()
  for _, w in ipairs(hl.get_windows()) do
    if w.floating and w.at and w.size and not onscreen(w) then
      hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
    end
  end
end
-- Wait for Hyprland to finish moving things before checking.
local function rescue_later() hl.timer(rescue_offscreen, { timeout = 500, type = "oneshot" }) end
for _, event in ipairs({ "monitor.added", "monitor.removed", "config.reloaded", "window.move_to_workspace" }) do
  hl.on(event, rescue_later)
end

-- This machine's monitors and HDR (hypr/hosts/<hostname>.lua), if it has a file.
do
  local f = io.open("/etc/hostname")
  local host = f and f:read("l")
  if f then f:close() end
  local path = os.getenv("HOME") .. "/.config/hypr/hosts/" .. (host or "") .. ".lua"
  local exists = io.open(path)
  if host and exists then exists:close(); dofile(path) end
end
