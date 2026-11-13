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
  mode = "1920x1080@240.00",
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

-- Gaming. Steam/Proton windows have the class steam_app_<appid>; for other
-- launchers, find the class with `hyprctl clients | grep class` while the game
-- runs. Later rules win, so put per-game exceptions below the general one.
-- After editing: hyprctl reload && hyprctl configerrors

-- Class regex for "every Steam game". Hyprland uses regex, not Lua patterns:
-- write [0-9] for a digit and [.] for a dot.
local games = "^steam_app_[0-9]+$"

hl.config({
  -- Lets windows tear (lower input lag, but a frame can show two images).
  -- Only applies to fullscreen windows that ask for it with `immediate`.
  general = { allow_tearing = true },

  -- Fullscreen windows skip the compositor: 0 off, 1 every fullscreen window,
  -- 2 only detected games (1 can glitch video and browsers).
  render = { direct_scanout = 2 },

  -- Variable refresh rate stays off, these monitors have no FreeSync. With one:
  -- 3 = fullscreen games/video only, and set vrr = 3 in its hl.monitor() too,
  -- which overrides this.
  misc = { vrr = 0 },
})

-- Delete a line to turn that effect off.
hl.window_rule({
  name = "games",
  match = { class = games },

  fullscreen = true,
  -- Tear while fullscreen. Remove for games that flicker with it.
  immediate = true,
  -- No blur or animations on the game window.
  no_blur = true,
  no_anim = true,
  -- No idle lock while the game is fullscreen. Also: "none", "always", "focus".
  idle_inhibit = "fullscreen",

  -- Slot 1 of the 240Hz monitor (DP-3). With monitor-workspaces it owns ids
  -- 11-20 and the 144Hz one 1-10, so use 1 if they ever swap. Check with:
  --   cat ~/.local/state/omarchy/monitor-workspaces   (block 0 = 1-10, 1 = 11-20)
  --   hyprctl workspaces | grep -E "workspace ID|monitor:"
  --   hyprctl monitors | grep -E "^Monitor|@"
  -- The solo-workspaces plugin keeps games alone on it (same pattern in
  -- ~/.config/hypr/solo-workspaces.lua); a busy workspace sends the game to
  -- the nearest empty one.
  workspace = "11",
})

-- Per-game overrides: copy a block, change the class, put it below "games".
-- Game that flickers with tearing:
-- hl.window_rule({ match = { class = "^steam_app_1245620$" }, immediate = false })
-- Non-Steam game:
-- hl.window_rule({ match = { class = "^Minecraft.*" }, fullscreen = true, immediate = true })
-- Floating, fixed size:
-- hl.window_rule({ match = { class = "^steam_app_12345$" }, float = true, size = "1280 720", center = true })

-- Steam launch options that pair with this:
--   gamemoderun %command%        performance mode (pacman -S gamemode)
--   mangohud %command%           fps overlay (pacman -S mangohud)
--   gamescope -f -W 1920 -H 1080 -r 240 -- %command%   own fullscreen layer

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 1,

     -- Change to niri-like side-scrolling layout.
     --layout = "scrolling",
  },
})
