-- Personal Hyprland settings on top of Omarchy's defaults. The rest of
-- ~/.config/hypr stays stock, so this is the only Hyprland file tracked here.
--
-- Setup: ~/.config/hypr/hyprland.lua needs two changes, since this file is
-- loaded from there and runs after Omarchy's defaults.
--
-- 1. Before `require("default.hypr.omarchy")`, uncomment this so Omarchy's
--    preinstalled app/webapp binds are skipped (too late to set it here):
--      omarchy_preinstalled_bindings = false
--
-- 2. At the end of the file, load this one:
--      dofile(os.getenv("HOME") .. "/Projects/dotfiles/omarchy/hypr/custom.lua")
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

-- https://wiki.hypr.land/configuring/core/config-options/#opacity
hl.window_rule({
    -- Which windows the rule applies to, matched by window class (".*" = all).
    match = { class = ".*" },
    -- Window opacity (0.0 = fully transparent, 1.0 = fully opaque).
    opacity = 1.0,
})

hl.monitor({
  output = "desc:AOC 2590G4 0x000210C1",
  mode = "1920x1080@144.00",
  position = "-1920x0",
  scale = 1,
  vrr = 0,
  bitdepth = 10,
  sdr_min_luminance = 0.2,
  sdr_max_luminance = 80,
})

hl.monitor({
  output = "desc:AOC C27G4ZXU 1O0Q7JA008205",
  mode = "1920x1080@280.00",
  position = "0x0",
  scale = 1,
  vrr = 0,
  bitdepth = 10,
  sdr_min_luminance = 0.2,
  sdr_max_luminance = 80,
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners.
    rounding = 0,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    dim_inactive = true,
    dim_strength = 0.1,
  },
})
