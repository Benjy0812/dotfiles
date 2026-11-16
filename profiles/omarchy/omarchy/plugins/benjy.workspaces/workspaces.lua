-- Workspace groups: each monitor has GROUPS groups of 10 workspaces.
-- Group 1 is Omarchy's own per-monitor 1-10 (default/hypr/monitor-workspaces.lua).
-- Groups 2+ are named workspaces "g<group>-b<block>-<slot>", keyed by the
-- monitor's Omarchy block so they belong to the physical monitor. They must be
-- named: Omarchy renumbers any numbered workspace outside a monitor's block
-- into group 1 on every config reload, but leaves named ones (id < 0) alone.
--
-- SUPER + 1-0 (and SHIFT / SHIFT+ALT moves) act on the focused monitor's
-- current group. SUPER + Page Down / Page Up switch group, keeping the slot.
--
-- Workspaces.qml next to this file is the bar widget showing the current group.
--
-- shortcut: a config reload or monitor change
-- snaps each monitor back to group 1 (windows in 2+ stay put). Upgrade by
-- reapplying each monitor's group on config.reloaded if that bothers you.

local GROUPS = 3
local SLOTS = 10
local M = {}

-- Group and slot of a workspace name; numbered workspaces are group 1.
function M.parse(name, id)
  local g, s = tostring(name or ""):match("^g(%d+)%-b%d+%-(%d+)$")
  if g then return tonumber(g), tonumber(s) end
  if id and id > 0 then return 1, (id - 1) % SLOTS + 1 end
  return 1, 1
end

-- The bar names its own monitor; keys act on the focused one.
local function on(monitor_name)
  local monitor = monitor_name and hl.get_monitor(monitor_name)
  if monitor and not monitor.focused then
    hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
  end
end

local function current()
  local ws = hl.get_active_workspace()
  return M.parse(ws and ws.name, ws and ws.id)
end

local function target(group, slot)
  local monitor = hl.get_active_monitor()
  local block = (o.workspaces.workspace_id(monitor, 1) - 1) // SLOTS
  return ("name:g%d-b%d-%d"):format(group, block, slot)
end

local function go(group, slot)
  if group == 1 then return o.workspaces.focus(slot)() end
  hl.dispatch(hl.dsp.focus({ workspace = target(group, slot) }))
end

local function action(fn, expression)
  o.bind_expressions[fn] = expression
  return fn
end

local function arg(monitor_name)
  return monitor_name and (", %q"):format(monitor_name) or ""
end

function M.focus(slot, monitor_name)
  return action(function()
    on(monitor_name)
    go((current()), slot)
  end, "o.groups.focus(" .. slot .. arg(monitor_name) .. ")")
end

function M.move_window(slot, follow)
  return action(function()
    local group = current()
    if group == 1 then return o.workspaces.move_window(slot, follow)() end
    hl.dispatch(hl.dsp.window.move({ workspace = target(group, slot), follow = follow ~= false }))
  end, "o.groups.move_window(" .. slot .. (follow == false and ", false" or "") .. ")")
end

function M.cycle(step, monitor_name)
  return action(function()
    on(monitor_name)
    local group, slot = current()
    go((group - 1 + step) % GROUPS + 1, slot)
  end, "o.groups.cycle(" .. step .. arg(monitor_name) .. ")")
end

o.groups = M

-- hl is only absent when the self-test loads this file.
if o.rebind then
  for slot = 1, SLOTS do
    local key = "code:" .. (slot + 9)
    o.rebind("SUPER + " .. key, "Switch to workspace " .. slot .. " in group", M.focus(slot))
    o.rebind("SUPER + SHIFT + " .. key, "Move window to workspace " .. slot .. " in group", M.move_window(slot))
    o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. slot .. " in group", M.move_window(slot, false))
  end
  o.bind("SUPER + Next", "Next workspace group", M.cycle(1))
  o.bind("SUPER + Prior", "Previous workspace group", M.cycle(-1))
end

return M
