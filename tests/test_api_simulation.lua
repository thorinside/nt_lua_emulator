local ntApi = require("modules.nt_api")
local helpers = require("modules.helpers")
local processor = require("modules.signal_processor")
local simulated = require("modules.simulated_algorithms")
require("modules.constants")
local function equal(actual, expected, message)
    assert(actual == expected, (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-8, tostring(actual) .. " ~= " .. tostring(expected))
end

local drawn = {}
local display = {
    createDrawingEnvironment = function() return {} end,
    setDisplayMode = function() end,
    drawText = function(x, y, text) drawn[#drawn + 1] = text end
}
local script = {parameterOffset = 1, draw = function() return true end}
local definitions = {{"Speed", 0, 100, 50, kHz, kBy10}, {"Mode", {"Off", "On", "Auto"}, 1}}
for i = 3, 13 do definitions[i] = {"Parameter " .. i, 0, 100, 50, kPercent} end
local parameters = helpers.parseScriptParameters(definitions)
helpers.updateScriptParameters(parameters, script)
local preset = simulated.create()
processor.init({currentOutputs = {}})
local api, runtime = ntApi.create({
    display = display, helpers = helpers,
    getScript = function() return script end,
    getScriptParameters = function() return parameters end,
    getAlgorithms = function() return preset end,
    getBusVoltage = processor.getBusVoltage
})

-- Standard pots select page, select within page, then adjust directionally.
equal(api.getCurrentParameter(0), 2)
api.standardPot1Turn(1)
equal(api.getCurrentParameter(0), 14, "last page, clamped within page")
api.standardPot2Turn(0)
equal(api.getCurrentParameter(0), 13)
api.standardPot2Turn(1)
equal(api.getCurrentParameter(0), 14)
api.standardPot1Turn(0)
api.standardPot2Turn(0.2)
equal(api.getCurrentParameter(0), 2)
api.standardPot3Turn(0.2) -- Anchor without a jump.
near(api.getParameter(0, 2), 5)
api.standardPot3Turn(0.3)
near(api.getParameter(0, 2), 6)
api.standardPot3Turn(0.1)
near(api.getParameter(0, 2), 4)
api.focusParameter(0, 3)
for i = 1, 30 do api.standardPot3Turn(0.1 + i / 100) end
equal(api.getParameter(0, 3), 2, "small enum movements accumulate")
api.standardPot3Turn(0 / 0)
equal(api.getParameter(0, 3), 2)
api.focusParameter(0, 999)
equal(api.getCurrentParameter(0), 3, "invalid focus ignored")
api.setParameter(0, 2, 0 / 0)
near(api.getParameter(0, 2), 4)

-- Bus numbers identify physical buses, NOT script slots. Remapping an output
-- moves its voltage to the corresponding physical output bus.
local inputs = processor.getCurrentInputs()
inputs[7] = 3.25
processor.updateOutputs({[2] = -4.5}, {[2] = 8})
equal(processor.prepareScriptInputValues(1, {[1] = 7})[1], 3.25)
equal(api.getBusVoltage(0, 6), 3.25)
equal(api.getBusVoltage(0, 19), 0, "output before the only processing algorithm")
equal(api.getBusVoltage(1, 19), -4.5, "mapped physical output after script")
equal(api.getBusVoltage(#preset, 19), -4.5, "final output stage")
equal(api.getBusVoltage(1, 13), 0, "unpatched physical output")
processor.setOutput(8, 2.5)
equal(api.getBusVoltage(1, 19), 2.5, "live output read")
assert(processor.setAuxBusVoltage(64, 7.5))
equal(api.getBusVoltage(0, 63), 7.5)
equal(api.getBusVoltage(-1, 6), 0)
equal(api.getBusVoltage(#preset + 1, 6), 0)
equal(api.getBusVoltage(0, 6.5), 0)
equal(api.getBusVoltage(0, 64), 0)

-- Both I2C forms use isolated per-address, wrapping 8-bit register banks.
api.sendI2CCommand(0x32, 0xFE, 17, 18, 19)
local response = api.sendI2CGetter(0x32, 4, {0xFE})
equal(table.concat(response, ","), "17,18,19,0")
api.sendI2CCommand(0x33, {0xFE, 90})
equal(api.sendI2CGetter(0x33, 1, 0xFE)[1], 90)
equal(api.sendI2CGetter(0x32, 1, 0xFE)[1], 17)
equal(api.sendI2CGetter(0x34, 1, 0xFE)[1], 0)
equal(api.sendI2CGetter(0x32, 1025, 0), nil)
equal(api.sendI2CGetter(nil, 2, 0), nil)
api.sendI2CCommand(nil, 0, 1)
api.sendI2CCommand(0x32, {0xFE, 256})
equal(api.sendI2CGetter(0x32, 1, 0xFE)[1], 17)
local history = runtime.getI2CHistory()
history[1].bytes[2] = 255
equal(runtime.getI2CHistory()[1].bytes[2], 17)
for i = 1, 100 do api.sendI2CGetter(0x32, 0, 0) end
equal(#runtime.getI2CHistory(), 64, "bounded I2C monitor")

-- All modes draw useful views; UI mode delegates to the user's draw callback.
equal(runtime.drawDisplayMode(), false)
for _, mode in ipairs({"overview", "meters", "parameters", "menu"}) do
    drawn = {}
    api.setDisplayMode(mode)
    equal(runtime.drawDisplayMode(), true, mode)
    assert(#drawn > 0)
end
api.setDisplayMode("meters")
drawn = {}
runtime.drawDisplayMode()
equal(#drawn, 21, "all 12 inputs and 8 outputs shown")
api.setDisplayMode("ui")
equal(runtime.drawDisplayMode(), false)
api.exit()
equal(runtime.drawDisplayMode(), true)
api.setDisplayMode("invalid")
equal(runtime.drawDisplayMode(), true)
api.setDisplayMode("ui")
equal(runtime.drawDisplayMode(), false)
api.focusParameter(0, 3)
drawn = {}
api.drawParameterLine(0, 3, 0)
equal(drawn[1], "Mode: On", "enum label rather than integer")
api.focusParameter(1, api.findParameter(1, "Decay"))
drawn = {}
api.drawAlgorithmUI(1)
assert(table.concat(drawn, "\n"):find("Decay: 2.5 s", 1, true))

-- Script manager renders built-in modes without calling the user's draw.
local manager = require("modules.script_manager")
local drawCalls = 0
script.draw = function() drawCalls = drawCalls + 1; return true end
script._emulatorDrawDisplay = runtime.drawDisplayMode
manager.init({safeScriptCall = function(callback, self, ...) return callback(self, ...) end})
manager.setScript(script)
api.setDisplayMode("parameters")
manager.callScriptDraw()
equal(drawCalls, 0)
api.setDisplayMode("ui")
manager.callScriptDraw()
equal(drawCalls, 1)
-- Built-in views own the pots; custom UI gets its callback, and absent script
-- handlers delegate to standard controls rather than swallowing the event.
local callbacks
local customPotCalls = 0
script._emulatorHandlePot = runtime.handlePot
script.pot1Turn = function() customPotCalls = customPotCalls + 1 end
manager.controls = {setCallbacks = function(value) callbacks = value end}
manager.setupControlCallbacks(script)
api.setDisplayMode("overview")
callbacks.onPotChange(1, 1)
equal(api.getCurrentAlgorithm(), #preset - 1)
equal(customPotCalls, 0)
api.setDisplayMode("ui")
callbacks.onPotChange(1, 0)
equal(customPotCalls, 1)
script.pot1Turn = nil
local fallbackCalls = 0
_G.standardPot1Turn = function() fallbackCalls = fallbackCalls + 1 end
callbacks.onPotChange(1, 0)
equal(fallbackCalls, 1)

-- A gate callback sees the updated voltage at its physical bus immediately.
processor.init({scriptManager = {callScriptGate = function()
    equal(processor.getBusVoltages(0)[1], 5)
end}})
processor.setInputClock(1, true)
processor.updateInputs({[1] = 1}, {inputs = {kGate}, gate = function() end}, {})
print("API simulation tests passed")
