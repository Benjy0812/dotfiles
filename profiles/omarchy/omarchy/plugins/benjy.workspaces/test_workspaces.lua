-- Run: lua test_workspaces.lua. Checks the workspace-name parser.
o = { bind_expressions = {} }
local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local M = dofile(dir .. "workspaces.lua")

local function check(name, id, g, s)
  local got_g, got_s = M.parse(name, id)
  assert(got_g == g and got_s == s, ("%s/%s: got %s,%s want %s,%s"):format(name, id, got_g, got_s, g, s))
end

check("g2-b1-3", -1337, 2, 3)
check("g3-b0-10", -5, 3, 10)
check("13", 13, 1, 3)
check("20", 20, 1, 10)
check("special:scratchpad", -98, 1, 1)
check("g2-bx-3", -2, 1, 1)
print("ok")
