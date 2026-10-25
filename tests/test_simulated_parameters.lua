local helpers = require("modules.helpers")
local simulated = require("modules.simulated_algorithms")
local ntApi = require("modules.nt_api")
require("modules.constants")

local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local preset = simulated.create()
local script = {parameterOffset = 1}
local parameters = helpers.parseScriptParameters({
    {"Speed", 0, 100, 50, kHz, kBy10},
    {"Mode", {"Off", "On"}, 1}
})
helpers.updateScriptParameters(parameters, script)
local api = ntApi.create({
    display = {createDrawingEnvironment = function() return {} end},
    helpers = helpers,
    getScript = function() return script end,
    getScriptParameters = function() return parameters end,
    getAlgorithms = function() return preset end
})

-- The exact console example from the feature request.
local t = api.getParameterInfo(1, 1)
equal(t.name, "Bypass")
equal(t.min, 0)
equal(t.max, 1)
equal(t.def, 0)
equal(t.unit, 1)
equal(t.scaling, 0)
equal(t.enumStrings[1], "Off")
equal(t.enumStrings[2], "On")

-- Every exposed index can be discovered, inspected, read, and written.
equal(api.getAlgorithmName(5), "VCO")
equal(api.findAlgorithm("VCO"), 5)
equal(api.getParameterInfo(5, 1).name, "Bypass")
equal(api.getParameterInfo(5, 3).enumStrings[5], "Pulse")
api.focusParameter(5, 3)
equal(api.getCurrentAlgorithm(), 5)
api.setParameter(5, 3, 4)
equal(api.getParameter(5, 3), 4)
api.setParameter(5, 3, 0)
equal(api.getAlgorithmName(6), nil)
equal(api.getParameterCount(0), nil)
equal(api.getParameterInfo(0, 1), nil)
equal(api.getParameterInfo(6, 1), nil)
for algorithm = 1, api.getAlgorithmCount() do
    for index = 1, api.getParameterCount(algorithm) do
        local info = assert(api.getParameterInfo(algorithm, index))
        equal(api.getParameterName(algorithm, index), info.name)
        equal(api.findParameter(algorithm, info.name), index)
        local scale = 10 ^ info.scaling
        equal(api.getParameter(algorithm, index), info.def / scale)
        api.setParameterNormalized(algorithm, index, 1, false)
        equal(api.getParameter(algorithm, index), info.max / scale)
        api.setParameter(algorithm, index, info.min / scale, false)
        equal(api.getParameter(algorithm, index), info.min / scale)
        -- Metadata describes defaults, not the changing current value.
        equal(api.getParameterInfo(algorithm, index).def, info.def)
        api.setParameter(algorithm, index, info.def / scale, false)
    end
    equal(api.getParameterInfo(algorithm, api.getParameterCount(algorithm) + 1), nil)
end

-- Script system parameters do not overwrite script-defined parameters.
equal(api.findParameter(1, "Bypass"), 1)
equal(api.findParameter(1, "Speed"), 2)
api.setParameter(1, 1, 1)
equal(api.getParameter(1, 1), 1)
equal(script.parameters[1], 5)
api.setParameter(1, 2, 7.5)
equal(script.parameters[1], 7.5)
equal(api.getCurrentParameter(1), 2)

-- Bypass pauses processing but keeps drawing and parameter control available.
local manager = require("modules.script_manager")
manager.init({safeScriptCall = function(callback, self, ...)
    return callback(self, ...)
end})
manager.setScript(script)
local calls = {step = 0, gate = 0, trigger = 0, midiMessage = 0, draw = 0}
for name in pairs(calls) do
    local callbackName = name
    script[name] = function()
        calls[callbackName] = calls[callbackName] + 1
        return true
    end
end
local function process()
    manager.callScriptStep(0.001, {})
    manager.callScriptGate({input = 1, rising = true})
    manager.callScriptTrigger({input = 1})
    manager.callScriptMidiMessage({})
    manager.callScriptDraw()
end
process()
equal(calls.step, 0)
equal(calls.gate, 0)
equal(calls.trigger, 0)
equal(calls.midiMessage, 0)
equal(calls.draw, 1)
api.setParameterNormalized(1, api.findParameter(1, "Bypass"), 0)
process()
equal(calls.step, 1)
equal(calls.gate, 1)
equal(calls.trigger, 1)
equal(calls.midiMessage, 1)
equal(calls.draw, 2)

local decay = api.findParameter(2, "Decay")
api.setParameter(2, decay, 3.7)
equal(api.getParameter(2, decay), 3.7)
equal(api.getParameterInfo(2, decay).scaling, 1)
api.setParameter(2, decay, 999)
equal(api.getParameter(2, decay), 30)
api.setParameterNormalized(2, decay, -1)
equal(api.getParameter(2, decay), 0.1)
local filter = api.findAlgorithm("Filter")
local kind = api.findParameter(filter, "Type")
api.setParameter(filter, kind, 1.6)
equal(api.getParameter(filter, kind), 2)
equal(api.getParameterInfo(filter, kind).enumStrings[3], "Band-pass")

-- Recreating a preset resets values; no state leaks between loads.
equal(simulated.create()[1].systemParams[1].current, 0)
equal(simulated.create()[2].params[3].current, 25)
t.enumStrings[1] = "Changed"
equal(api.getParameterInfo(2, 1).enumStrings[1], "Off")
print("Simulated parameter tests passed")
