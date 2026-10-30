-- Per-monitor workspaces for Hyprland's Lua config (0.55+), mangowm-style:
-- every monitor gets its own workspaces 1-10 on SUPER+1..0.
--
-- Under the hood each monitor owns a block of real workspace ids: the first
-- monitor in `monitors` owns 1-10, the second 11-20, and so on. Workspace rules
-- pin each block to its monitor, and the binds below translate "slot N" into
-- the id inside the focused monitor's block. Widget.qml reads the same mapping
-- back from the workspace rules, so there is nothing to configure there.

local M = { monitors = {}, per_monitor = 10 }

-- Settings live outside the plugin so reinstalling keeps them; dotfiles.bash setup
-- creates this file from config.default.lua. A mistake in it shows up in
-- `hyprctl configerrors`.
M.config = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/monitor-workspaces.lua"
local file = io.open(M.config, "r")
if file then
  file:close()
  for key, value in pairs(dofile(M.config) or {}) do M[key] = value end
end

local function matches(entry, monitor)
  return entry == monitor.name or entry == monitor.description
end

local function monitor_index(monitor)
  for i, entry in ipairs(M.monitors) do
    if matches(entry, monitor) then return i - 1 end
  end
  M.monitors[#M.monitors + 1] = monitor.name
  return #M.monitors - 1
end

local function workspace_id(monitor, slot)
  return tostring(monitor_index(monitor) * M.per_monitor + slot)
end

-- workspace id -> monitor it is currently pinned to, so each rule is set once.
local pinned = {}

local function pin_workspaces(monitor)
  for slot = 1, M.per_monitor do
    local id = workspace_id(monitor, slot)
    if pinned[id] ~= monitor.name then
      pinned[id] = monitor.name
      hl.workspace_rule({ workspace = id, monitor = monitor.name, default = slot == 1 })
    end
  end
end

-- rawlen, not ipairs: omarchy-menu-keybindings evaluates this file against a
-- stub `hl` whose results answer every index, so ipairs would never terminate.
local connected = hl.get_monitors()
for i = 1, rawlen(connected) do
  pin_workspaces(connected[i])
end
-- Reserve the blocks of listed monitors that are not plugged in right now.
for _, entry in ipairs(M.monitors) do
  local present = false
  for i = 1, rawlen(connected) do
    if matches(entry, connected[i]) then present = true end
  end
  if not present then
    pin_workspaces({ name = entry:find(" ") and "desc:" .. entry or entry, description = entry })
  end
end
hl.on("monitor.added", pin_workspaces)

local function on_focused_monitor(make_dispatcher)
  return function()
    local monitor = hl.get_active_monitor()
    if monitor then hl.dispatch(make_dispatcher(monitor)) end
  end
end

local function focus_slot(slot)
  return on_focused_monitor(function(monitor)
    return hl.dsp.focus({ workspace = workspace_id(monitor, slot) })
  end)
end

local function move_to_slot(slot, follow)
  return on_focused_monitor(function(monitor)
    return hl.dsp.window.move({ workspace = workspace_id(monitor, slot), follow = follow })
  end)
end

-- Slot 1..per_monitor of a workspace id inside its monitor's block.
local function slot_of(id)
  return (id - 1) % M.per_monitor + 1
end

-- The connected monitor whose block comes after this one's, wrapping around.
local function next_monitor(monitor)
  local own = monitor_index(monitor)
  local after, first
  local connected = hl.get_monitors()
  for i = 1, rawlen(connected) do
    local index = monitor_index(connected[i])
    if index > own and (not after or index < after.index) then after = { monitor = connected[i], index = index } end
    if index ~= own and (not first or index < first.index) then first = { monitor = connected[i], index = index } end
  end
  local pick = after or first
  return pick and pick.monitor
end

-- Move the focused window onto whatever is showing on the monitor in
-- `direction` ("l", "r", "u", "d"), and follow it there.
local function send_window_toward(direction)
  return function()
    local target = hl.get_monitor(direction)
    local shown = target and hl.get_active_workspace(target.name)
    if shown then hl.dispatch(hl.dsp.window.move({ workspace = tostring(shown.id), follow = true })) end
  end
end

-- Move every window of the focused workspace to the same slot on the monitor
-- in `direction`, then follow. Replaces moving the workspace itself, which
-- would carry its id out of its monitor's block.
local function send_workspace_toward(direction)
  return function()
    local monitor = hl.get_active_monitor()
    local target = hl.get_monitor(direction)
    local current = monitor and hl.get_active_workspace(monitor.name)
    if not (target and current) then return end

    local destination = workspace_id(target, slot_of(current.id))
    local windows = hl.get_workspace_windows(current.id)
    for i = 1, rawlen(windows) do
      hl.dispatch(hl.dsp.window.move({ workspace = destination, follow = false, window = "address:" .. windows[i].address }))
    end
    hl.dispatch(hl.dsp.focus({ workspace = destination }))
  end
end

-- Move the focused window to `slot` on the next monitor, staying here.
local function send_window_to_next_monitor(slot)
  return function()
    local monitor = hl.get_active_monitor()
    local other = monitor and next_monitor(monitor)
    if other then hl.dispatch(hl.dsp.window.move({ workspace = workspace_id(other, slot), follow = false })) end
  end
end

-- Replace Omarchy's global 1-10 binds (default/hypr/bindings/tiling.lua).
for slot = 1, M.per_monitor do
  local key = "code:" .. tostring(slot + 9)
  -- Also clear the plain digit spelling in case Omarchy ever switches to it.
  for _, k in ipairs({ key, tostring(slot % 10) }) do
    hl.unbind("SUPER + " .. k)
    hl.unbind("SUPER + SHIFT + " .. k)
    hl.unbind("SUPER + SHIFT + ALT + " .. k)
  end
  o.bind("SUPER + " .. key, "Switch to monitor workspace " .. slot, focus_slot(slot))
  o.bind("SUPER + SHIFT + " .. key, "Move window to monitor workspace " .. slot, move_to_slot(slot, true))
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to monitor workspace " .. slot, move_to_slot(slot, false))
  o.bind("SUPER + CTRL + SHIFT + " .. key, "Move window to workspace " .. slot .. " on next monitor", send_window_to_next_monitor(slot))
end

local directions = { LEFT = "l", RIGHT = "r", UP = "u", DOWN = "d" }
local direction_names = { l = "left", r = "right", u = "up", d = "down" }
for arrow, direction in pairs(directions) do
  local name = direction_names[direction]
  o.bind("SUPER + CTRL + SHIFT + " .. arrow, "Move window to " .. name .. " monitor", send_window_toward(direction))
  -- Omarchy's version moves the workspace itself to the other monitor.
  hl.unbind("SUPER + SHIFT + ALT + " .. arrow)
  o.bind("SUPER + SHIFT + ALT + " .. arrow, "Move workspace windows to " .. name .. " monitor", send_workspace_toward(direction))
end

-- Next/previous cycle only the focused monitor's open workspaces ("m"), not
-- every open workspace across screens ("e") like Omarchy's default.
for keys, target in pairs({ ["SUPER + TAB"] = "m+1", ["SUPER + SHIFT + TAB"] = "m-1", ["SUPER + mouse_down"] = "m+1", ["SUPER + mouse_up"] = "m-1" }) do
  hl.unbind(keys)
  o.bind(keys, "Cycle monitor workspaces " .. target, hl.dsp.focus({ workspace = target }))
end

-- Same actions for scripts, e.g.
--   hyprctl eval 'monitor_workspaces.send_window_toward("l")()'
-- workspace_id is also used by benjy.solo-workspaces.
M.workspace_id = workspace_id
M.focus_slot = focus_slot
M.move_to_slot = move_to_slot
M.send_window_toward = send_window_toward
M.send_workspace_toward = send_workspace_toward
M.send_window_to_next_monitor = send_window_to_next_monitor
monitor_workspaces = M

return M
