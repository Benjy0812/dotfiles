-- Run: lua test_is_solo.lua. Tests the real M.matches and M.slot_on from solo-workspaces.lua.
-- Stubs the Hyprland globals the plugin calls at load time, and hides HOME and
-- XDG_CONFIG_HOME so no real settings file is read.
hl = setmetatable({ dsp = { window = {} } }, { __index = function() return function() end end })
hl.get_workspace_windows = function() return {} end
-- Omarchy's monitor-workspaces module, published as o.workspaces: DP-3 owns 11-20.
o = { workspaces = { workspace_id = function(m, s) return (m.name == "DP-3" and 10 or 0) + s end } }
local getenv = os.getenv
os.getenv = function(name)
  if name == "HOME" or name == "XDG_CONFIG_HOME" then return "/nonexistent" end
  return getenv(name)
end
local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local M = dofile(dir .. "solo-workspaces.lua")
os.getenv = getenv

local fails = 0
local function check(entry, class, want)
  if M.matches({ entry }, class) ~= want then
    fails = fails + 1
    print(("FAIL: %s vs %s, want %s"):format(entry, class, tostring(want)))
  end
end

check("^steam_app_%d+$", "steam_app_1422450", true)
check("^steam_app_%d+$", "steam", false)
check("^steam_app_%d+$", "STEAM_APP_1422450", false)
check("org.jellyfin.JellyfinDesktop", "org.jellyfin.jellyfindesktop", true)
check("org.jellyfin.JellyfinDesktop", "org.jellyfin.JellyfinDesktopX", false)
check("^steam_app_(%d+$", "steam_app_1422450", false)
check("^app%D+$", "app123", false)
check("^app%D+$", "appx", true)

-- A bad pattern is false, notifies once, and does not notify again on the next event.
local calls = 0
local real_exec = hl.exec_cmd
hl.exec_cmd = function() calls = calls + 1 end
check("^bad_(%d+", "bad_1", false)
if calls ~= 1 then fails = fails + 1; print("FAIL: want 1 notify, got " .. calls) end
check("^bad_(%d+", "bad_1", false)
if calls ~= 1 then fails = fails + 1; print("FAIL: bad pattern notified again, got " .. calls) end
hl.exec_cmd = real_exec

-- Workspace 11 on DP-3 is that monitor's slot 1 (Omarchy's ids are numbers).
if M.slot_on({ name = "DP-3" }, 11) ~= 1 then fails = fails + 1; print("FAIL: workspace 11 on DP-3 is not slot 1") end

if fails > 0 then os.exit(1) end
print("all 11 passed")
