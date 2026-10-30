-- Solo workspaces for Hyprland's Lua config (0.55+): listed apps always get a
-- workspace to themselves. When one opens next to other windows it moves to
-- the nearest empty workspace on the same monitor (1, 3 and 4 in use, opened
-- on 3 -> it goes to 2), and other windows opened onto its workspace are
-- moved off the same way.
--
-- Settings are in ~/.config/hypr/solo-workspaces.lua.
--
-- Works alone with plain workspaces 1-10, or together with
-- benjy.monitor-workspaces, in which case "1-10" means the focused monitor's
-- own 1-10.

local defaults = { apps = {}, push_others = true, follow = true, slots = 10 }
local M = {}

-- Settings live outside the plugin so reinstalling keeps them; dotfiles.bash setup
-- creates this file from config.default.lua.
M.config = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/solo-workspaces.lua"

local function read_config()
  local file = io.open(M.config, "r")
  if not file then return "" end
  local text = file:read("*a")
  file:close()
  return text
end

local function apply(settings)
  for key, value in pairs(defaults) do M[key] = value end
  for key, value in pairs(settings or {}) do M[key] = value end
end

-- At startup a mistake in the file shows up in `hyprctl configerrors`.
local loaded = read_config()
apply(loaded ~= "" and dofile(M.config) or nil)

-- Hyprland only watches its own config files, so check this one every 2s and
-- apply edits in place. A broken edit keeps the last good settings.
hl.timer(function()
  local text = read_config()
  if text == loaded then return end
  loaded = text
  local chunk, err = load(text, "@" .. M.config)
  local ok, settings = pcall(chunk or error, err)
  if ok then
    apply(settings)
  else
    hl.exec_cmd("notify-send -u critical 'Solo workspaces' '" .. tostring(settings):gsub("'", "'\\''") .. "'")
  end
end, { timeout = 2000, type = "repeat" })

local function is_solo(class)
  if not class then return false end
  for _, app in ipairs(M.apps) do
    if app:lower() == class:lower() then return true end
  end
  return false
end

-- Real workspace id of `slot` on `monitor`, via monitor-workspaces if loaded.
local function workspace_for(monitor, slot)
  if monitor_workspaces and monitor_workspaces.workspace_id then
    return monitor_workspaces.workspace_id(monitor, slot)
  end
  return tostring(slot)
end

local function slot_on(monitor, id)
  for slot = 1, M.slots do
    if workspace_for(monitor, slot) == tostring(id) then return slot end
  end
end

-- Tiled windows on workspace `id`, other than `except`. Floating ones are
-- dialogs and popups and never count.
local function others(id, except)
  local list = {}
  local windows = hl.get_workspace_windows(id)
  for i = 1, rawlen(windows) do
    local w = windows[i]
    if w.address ~= except.address and not w.floating then list[#list + 1] = w end
  end
  return list
end

local function conflicts(window, id)
  for _, other in ipairs(others(id, window)) do
    if other.class ~= window.class and (is_solo(window.class) or (M.push_others and is_solo(other.class))) then
      return true
    end
  end
  return false
end

-- Where a window should go instead: for a solo app, a workspace that already
-- holds only that app; otherwise the empty slot closest to `from`, lower first.
local function destination(window, monitor, from)
  if is_solo(window.class) then
    for slot = 1, M.slots do
      local id = workspace_for(monitor, slot)
      local list = others(id, window)
      if slot ~= from and #list > 0 and not conflicts(window, id) then return id end
    end
  end
  for distance = 1, M.slots do
    for _, slot in ipairs({ from - distance, from + distance }) do
      if slot >= 1 and slot <= M.slots then
        local id = workspace_for(monitor, slot)
        if rawlen(hl.get_workspace_windows(id)) == 0 then return id end
      end
    end
  end
end

local function place(window)
  if not window or window.floating or not window.class or window.class == "" then return end
  local workspace = window.workspace
  local monitor = window.monitor
  if not (workspace and monitor) or workspace.special then return end

  local from = slot_on(monitor, workspace.id)
  if not from or not conflicts(window, workspace.id) then return end

  local target = destination(window, monitor, from)
  if not target then return end -- every slot is taken
  hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false, window = "address:" .. window.address }))
  if M.follow then hl.dispatch(hl.dsp.focus({ workspace = target })) end
end

hl.on("window.open", place)
-- Some apps only set their class after mapping.
hl.on("window.class", place)
-- Moving a window onto a solo app's workspace, or the app onto a busy one, is
-- sorted out the same way. Moves done by `place` land on a free workspace, so
-- they don't trigger another one.
--
-- A tiled window dragged with SUPER+mouse floats until it is dropped, and
-- its move to another monitor's workspace fires mid-drag. Remember it and
-- check again once it is tiled, which shows up as a window.update_rules.
-- Moving it right then, while the layout is still placing the dropped window,
-- leaves an empty slot behind, so wait a moment and look it up again.
local dragged = {}
local function place_after_drop(address)
  hl.timer(function()
    place(hl.get_window("address:" .. address))
  end, { timeout = 150, type = "oneshot" })
end
hl.on("window.move_to_workspace", function(window)
  if window and window.floating then
    dragged[window.address] = true
  else
    place(window)
  end
end)
hl.on("window.update_rules", function(window)
  if window and dragged[window.address] and not window.floating then
    dragged[window.address] = nil
    place_after_drop(window.address)
  end
end)
hl.on("window.close", function(window)
  if window then dragged[window.address] = nil end
end)

M.place = place
solo_workspaces = M

return M
