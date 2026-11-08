-- Run: lua test_is_solo.lua. Copy of the matching logic in is_solo (solo-workspaces.lua); keep in sync.
local function is_solo(apps, class)
  for _, app in ipairs(apps) do
    local a, c = app:lower(), class:lower()
    if a == c or (a:sub(1, 1) == "^" and c:match(a)) then return true end
  end
  return false
end

local fails = 0
local function check(entry, class, want)
  if is_solo({ entry }, class) ~= want then
    fails = fails + 1
    print(("FAIL: %s vs %s, want %s"):format(entry, class, tostring(want)))
  end
end

check("^steam_app_%d+$", "steam_app_1422450", true)
check("^steam_app_%d+$", "steam", false)
check("^steam_app_%d+$", "STEAM_APP_1422450", true)
check("org.jellyfin.JellyfinDesktop", "org.jellyfin.jellyfindesktop", true)
check("org.jellyfin.JellyfinDesktop", "org.jellyfin.JellyfinDesktopX", false)

if fails > 0 then os.exit(1) end
print("all 5 passed")
