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

-- Mesa (AMD/Intel) shader cache limit, raised so games like Wuthering Waves
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

-- ============================================================================
-- GAMING
-- ============================================================================
-- Everything here is aimed at Steam/Proton games, which all get the window
-- class "steam_app_<appid>". Find the class of any other game's window with:
--   hyprctl clients | grep -i -A3 class      (run it while the game is open)
-- Then reuse the rules below with that class (see "SPECIFIC GAMES" at the end).
--
-- Rules apply in order and later ones win, so put exceptions BELOW the general
-- ones. Check for typos after editing: hyprctl reload && hyprctl configerrors

-- The class pattern every rule below uses. It is a regex:
--   "^steam_app_[0-9]+$"             every Steam game (the default)
--   "^steam_app_3513350$"         one specific Steam game (appid is in its store URL)
--   "^(steam_app_[0-9]+|gamescope)$" Steam games plus gamescope windows
--   "^(lutris|heroic|.*[.]exe)$"   Lutris/Heroic launched games and bare Wine .exe windows
-- (Hyprland uses regex, not Lua patterns: write [0-9] for a digit and [.] for a dot.)
local games = "^steam_app_[0-9]+$"

-- --- Tearing / latency ------------------------------------------------------
-- allow_tearing only PERMITS tearing; nothing tears until a window rule
-- below asks for it. true = allowed, false = never (Omarchy's default).
-- Cost: with tearing a frame can show half old, half new image. Gain: lower
-- input lag, which matters in fast shooters. Needs the game fullscreen.
hl.config({
  general = {
    allow_tearing = true,
  },

  render = {
    -- Direct scanout: when a game is fullscreen and covers the whole monitor,
    -- its frames go straight to the screen and skip the compositor. Less lag
    -- and a bit less GPU load.
    --   0 = off
    --   1 = on for every fullscreen window (can glitch with video/browsers)
    --   2 = on only for fullscreen windows Hyprland detects as games (safe pick)
    direct_scanout = 2,
  },

  misc = {
    -- Variable refresh rate (FreeSync/G-Sync) is OFF: these monitors don't
    -- support it, so tearing (allow_tearing + `immediate` below) is the
    -- low-latency option instead. If you get a VRR monitor later: set this to 3
    -- (0 off, 1 always, 2 fullscreen only, 3 fullscreen games/video) AND change
    -- `vrr = 0` to `vrr = 3` in its hl.monitor() block, which overrides this.
    vrr = 0,
  },
})

-- --- Per-window rules for games --------------------------------------------
-- Each field below is an optional effect; delete a line to turn it off, or
-- copy the whole block for a different game.
hl.window_rule({
  name = "games",
  match = { class = games },

  -- Open the game fullscreen automatically (true) or leave it windowed
  -- (remove the line). Options: true | "maximize" for fullscreen with bar visible.
  fullscreen = true,

  -- Allow this window to tear. Only has an effect while the window is
  -- fullscreen AND general.allow_tearing is true. Turn off for games that
  -- flicker or look broken when tearing (some Proton titles do).
  immediate = true,

  -- No blur or animations on the game window: saves GPU time, avoids stutter
  -- when it opens/closes. Remove these if you want the game to fade in.
  no_blur = true,
  no_anim = true,

  -- Stop the screen locking/going idle while the game is fullscreen, so the
  -- lock screen doesn't appear mid-match with a controller. Options:
  -- "none" | "always" | "focus" (while focused) | "fullscreen" (while fullscreen).
  idle_inhibit = "fullscreen",

  -- Send every game to slot 1 of the 240Hz monitor (DP-3). With
  -- monitor-workspaces that monitor owns ids 11-20, so slot 1 is id 11; the
  -- 144Hz one owns 1-10. If the monitors ever swap blocks
  -- change 11 to 1. Check which monitor owns which block with:
  --   cat ~/.local/state/omarchy/monitor-workspaces   (block 0 = ids 1-10, 1 = 11-20)
  --   hyprctl workspaces | grep -E "workspace ID|monitor:"   (id -> monitor)
  --   hyprctl monitors | grep -E "^Monitor|@"                (monitor -> refresh rate)
  --   hyprctl clients | grep -E "class|workspace:"           (where each window is)
  -- The solo-workspaces plugin (see
  -- ~/.config/hypr/solo-workspaces.lua, which lists the same Steam pattern)
  -- keeps games alone: if 1 is busy the game goes to the nearest empty one.
  -- Delete the line to open on the current workspace.
  workspace = "11",
})

-- --- SPECIFIC GAMES ---------------------------------------------------------
-- Copy a block per game. Because it comes after "games", it overrides it.
-- Examples (uncomment and change the class to use):
--
-- A game that must stay windowed (e.g. it breaks in fullscreen):
-- hl.window_rule({
--   name = "game-windowed",
--   match = { class = "^steam_app_3513350$" },
--   fullscreen = false,
--   immediate = false,
-- })
--
-- A game that tears badly or flickers: just turn tearing off for it.
-- hl.window_rule({
--   name = "game-no-tearing",
--   match = { class = "^steam_app_1245620$" },
--   immediate = false,
-- })
--
-- A non-Steam game (find its class with hyprctl clients):
-- hl.window_rule({
--   name = "game-minecraft",
--   match = { class = "^Minecraft.*" },
--   fullscreen = true,
--   immediate = true,
-- })
--
-- Games you want on a different monitor or at a fixed size (floating):
-- hl.window_rule({
--   name = "game-float",
--   match = { class = "^steam_app_12345$" },
--   float = true,
--   size = "1280 720",
--   center = true,
-- })
--
-- Steam launch options (Steam > game > Properties) that pair with this:
--   gamemoderun %command%            CPU/GPU performance mode (pacman -S gamemode)
--   gamescope -f -W 1920 -H 1080 -r 240 -- %command%   own fullscreen/scaling layer
--   PROTON_ENABLE_WAYLAND=1 %command%   run Proton games as native Wayland
--   mangohud %command%               fps overlay (pacman -S mangohud)
