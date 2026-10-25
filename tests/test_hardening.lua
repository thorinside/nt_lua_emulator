-- No user configuration/state is read or modified by these tests.
local json = require("lib.dkjson")
local config = require("modules.config")
local ioState = require("modules.io_state")
local originalOpen = io.open
local contents, writes = {}, 0
io.open = function(path, mode)
    assert(path == "config.json" or path == "state.json", path)
    if mode == "r" then
        if contents[path] == nil then return nil end
        return {read = function() return contents[path] end, close = function() return true end}
    end
    writes = writes + 1
    return {write = function(_, value) contents[path] = value; return true end,
            close = function() return true end}
end
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
for _, bad in ipairs({"{", "null", "false", "42", '"text"', '{"midi":3,"osc":false,"script":true}'}) do
    contents["config.json"] = bad
    local cfg = config.load()
    equal(cfg.midi.selectedInput, -1); equal(cfg.osc.host, "127.0.0.1")
    contents["state.json"] = bad
    assert(type(ioState.loadStateFile()) == "table")
    local ok, state = ioState.loadIOState("test.lua")
    assert(not ok or type(state) == "table")
end
contents["config.json"] = nil
local first = config.load()
first.midi.destinationRoutes["1"] = true; first.osc.port = 42
equal(config.load().osc.port, 8000)
equal(config.load().midi.destinationRoutes["1"], nil)
contents["config.json"] = '{"midi":{"enabled":false,"selectedInput":-4,"selectedOutput":1.5,"destinationRoutes":{"1":false,"2":"false","8":true}},"osc":{"port":99999,"sendInterval":-1}}'
local cfg = config.load()
equal(cfg.midi.enabled, false); equal(cfg.midi.destinationRoutes["1"], false)
equal(cfg.midi.destinationRoutes["2"], nil); equal(cfg.midi.destinationRoutes["8"], true)
equal(cfg.midi.selectedInput, -1); equal(cfg.midi.selectedOutput, -1)
equal(cfg.osc.port, 8000); equal(cfg.osc.sendInterval, 0.001)
local cyclic = {}; cyclic.self = cyclic
local before, saved = writes, contents["config.json"]
assert(not config.save(cyclic)); equal(writes, before); equal(contents["config.json"], saved)
contents["state.json"] = '{"inputs":{"1":2,"2":"bad","-1":3},"inputModes":{"1":false,"2":{"clock":"false","scaling":4}},"window":{"x":0,"y":0,"width":-1,"height":600},"parameterValues":{"good":3,"bad":{}},"clockBPM":"fast"}'
local ok, state = ioState.loadIOState("test.lua")
assert(ok); equal(state.inputs["1"], 2); equal(state.inputs["2"], nil); equal(state.inputs["-1"], nil)
equal(state.inputModes["1"], nil); equal(state.inputModes["2"].clock, nil)
equal(state.inputModes["2"].scaling, 4); equal(state.window, nil)
equal(state.parameterValues.good, 3); equal(state.parameterValues.bad, nil); equal(state.clockBPM, nil)

-- File completion caches misses and never substitutes shell syntax in paths.
local popen = io.popen
local commands = {}
io.popen = function(command)
    commands[#commands + 1] = command
    return {lines = function() return function() return nil end end, close = function() return true end}
end
love = {graphics = {getDimensions = function() return 800, 600 end}}
contents["state.json"] = '{'
local dialog = require("modules.path_input_dialog")
dialog.open(function() end)
local input = "/tmp/$(touch NEVER_RUN)/it's empty/"
dialog.textinput(input)
equal(#commands, 1)
assert(commands[1]:find("'\\''", 1, true), "apostrophes must be escaped")
for i = 1, 100 do dialog.update(0.016) end
equal(#commands, 1)
dialog.keypressed("tab"); equal(#commands, 2)
dialog.keyreleased("tab"); dialog.keypressed("escape")
-- Unsupported popen must leave the dialog usable, without frame-by-frame retries.
io.popen = function() commands[#commands + 1] = "unsupported"; error("unsupported") end
dialog.open(function() end)
dialog.textinput("/missing/")
local attempts = #commands
for i = 1, 100 do dialog.update(0.016) end
equal(#commands, attempts)
dialog.keypressed("escape")
io.popen, io.open = popen, originalOpen
if package.config:sub(1, 1) ~= "\\" then
    local quote = require("modules.shell_path").quote
    -- printf is intentionally the only command: substitution-looking text stays literal.
    local value = "a' b $(printf injected) `printf injected` ; end"
    local pipe = assert(io.popen("printf '%s' " .. quote(value)))
    equal(pipe:read("*a"), value); pipe:close()
    equal(quote("-option"), "'./-option'")
end

-- Old ellipsis loops never terminated when the suffix itself did not fit.
local helpers = require("modules.helpers")
local calls = 0
local font = {getWidth = function(_, text)
    calls = calls + 1
    assert(calls < 1000, "text fitting must terminate with bounded work")
    -- Reject split UTF-8 sequences used by the test strings.
    assert(not text:find("\195[^\128-\191]"), "split UTF-8")
    assert(text:byte(-1) ~= 195, "split UTF-8 at end")
    return #text
end}
for _, width in ipairs({-1, 0, 1, 2, 3, 5, 10}) do
    calls = 0
    local lines = helpers.wrapAndEllipsizeText("a b c déééééééééééé", font, width, 2)
    assert(#lines <= 2)
    for _, line in ipairs(lines) do assert(font:getWidth(line) <= math.max(0, width)) end
end
calls = 0
helpers.wrapAndEllipsizeText(string.rep("x", 100000), font, 4, 1)
assert(calls < 50, "long-word fitting should use logarithmic width checks")
equal(#helpers.wrapAndEllipsizeText("hello", font, 100, 0), 0)
print("Hardening regression tests passed")
