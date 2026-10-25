-- Run via run_script_guard.sh: an external timeout catches watchdog regressions.
local guard = require("modules.script_guard")
local function pack(...) return {n = select("#", ...), ...} end
local hookCalls = 0
local function previousHook() hookCalls = hookCalls + 1 end
debug.sethook(previousHook, "", 1000)
local wasJit = jit and jit.status()
local values = pack(guard.call(function(a, b) return a, nil, b, false end, 12, 34))
assert(values.n == 5 and values[1] and values[2] == 12 and values[3] == nil and values[4] == 34 and values[5] == false)
local h, mask, count = debug.gethook()
assert(h == previousHook and count == 1000 and mask == "")
local ok, err = guard.call(function() error("ordinary error") end)
assert(not ok and tostring(err):find("ordinary error", 1, true))
assert(debug.gethook() == previousHook)
assert(not jit or jit.status() == wasJit)
debug.sethook()
local entered = 0
local function runaway() entered = entered + 1; while true do end end
ok, err = guard.call(runaway)
assert(not ok and tostring(err):find("budget exceeded", 1, true))
assert(guard.isDisabled(runaway) and entered == 1)
guard.call(runaway); assert(entered == 1, "timed-out callback must not run again")
assert(debug.gethook() == nil)
assert(not jit or jit.status() == wasJit)
-- Existing compiled helper loops must also obey the guard.
local function work(n) local x = 0; for i = 1, n do x = x + i end; return x end
for i = 1, 100 do work(10000) end
ok, err = guard.call(function() return work(10000000000) end)
assert(not ok and tostring(err):find("budget exceeded", 1, true))
-- Nested protected calls share a single outer budget instead of resetting it.
ok, err = guard.call(function()
    while true do guard.call(function() return 1 end) end
end)
assert(not ok and tostring(err):find("budget exceeded", 1, true))
-- A timeout swallowed by one pcall still marks the outer call as failed.
ok, err = guard.call(function() pcall(function() while true do end end); return "swallowed" end)
assert(not ok and tostring(err):find("budget exceeded", 1, true))
-- Prior hooks/JIT-disabled mode survive timeout cleanup too.
if jit then jit.off() end
debug.sethook(previousHook, "", 1000)
ok = guard.load(function() while true do end end)
assert(not ok and debug.gethook() == previousHook)
assert(not jit or not jit.status())
debug.sethook()
if jit and wasJit then jit.on() end
assert(guard.call(function() return true end), "healthy callbacks still work after errors")
print("Script watchdog tests passed")
