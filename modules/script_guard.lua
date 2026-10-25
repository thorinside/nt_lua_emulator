-- Best-effort watchdog for trusted development scripts, NOT a security sandbox.
-- Cannot interrupt blocking C/native calls, or code deliberately disabling hooks.
-- Disable JIT while guarded: compiled loops must not bypass instruction hooks.
local M = {}
local sethook, gethook = debug.sethook, debug.gethook
local protected, clock = pcall, os.clock
local unpackValues = table.unpack or unpack
local jitRuntime = jit
local disabled = setmetatable({}, {__mode = "k"})
local active
local timeout = setmetatable({}, {__tostring = function() return "Script execution budget exceeded; reload the script to retry" end})
local function pack(...) return {n = select("#", ...), ...} end
local function run(fn, seconds, instructions, ...)
    if disabled[fn] then return false, timeout end
    if active then return protected(fn, ...) end -- Nested SDK calls share the outer budget.
    local previousHook, mask, count = gethook()
    local wasJit = jitRuntime and jitRuntime.status()
    if jitRuntime then jitRuntime.off() end
    local state = {deadline = clock() + seconds, remaining = instructions}
    active = state
    local function hook()
        state.remaining = state.remaining - 10000
        if state.remaining <= 0 or clock() >= state.deadline then
            state.expired = true
            -- Remove our hook before unwinding so cleanup cannot itself time out.
            sethook()
            error(timeout, 0)
        end
    end
    sethook(hook, "", 10000)
    local result = pack(protected(fn, ...))
    sethook()
    active = nil
    if wasJit then jitRuntime.on() end
    if previousHook then sethook(previousHook, mask, count) end
    if state.expired then
        if type(fn) == "function" then disabled[fn] = true end
        return false, timeout
    end
    return unpackValues(result, 1, result.n)
end
function M.call(fn, ...) return run(fn, 0.05, 2000000, ...) end
function M.load(fn, ...) return run(fn, 1, 20000000, ...) end
function M.isDisabled(fn) return disabled[fn] == true end
return M
