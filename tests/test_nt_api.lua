local helpers = require("modules.helpers")
local nt_api = require("modules.nt_api")

local modes = {}
local drawn = {}
local midiMessages = {}
local i2cCommands = {}

local drawingEnvironment = {
    drawBox = function() end,
    drawCircle = function() end,
    drawLine = function() end,
    drawRectangle = function() end,
    drawSmoothCircle = function() end,
    drawSmoothLine = function() end,
    drawText = function() end,
    drawTinyText = function() end
}

local display = {
    createDrawingEnvironment = function()
        local result = {}
        for name, value in pairs(drawingEnvironment) do result[name] = value end
        return result
    end,
    setDisplayMode = function(mode)
        modes[#modes + 1] = mode
    end,
    drawText = function(...)
        drawn[#drawn + 1] = {...}
    end
}

local script = {
    name = "Test Script",
    parameterOffset = 1
}
local parameters = {
    {
        name = "Speed",
        type = "float",
        min = 0,
        max = 100,
        current = 50,
        default = 50,
        scale = 10
    },
    {
        name = "1:Mode",
        type = "integer",
        min = 0,
        max = 4,
        current = 1,
        default = 1,
        scale = 1
    },
    {
        name = "2:Mode",
        type = "integer",
        min = 0,
        max = 4,
        current = 2,
        default = 2,
        scale = 1
    }
}
helpers.updateScriptParameters(parameters, script)

local algorithms = {
    {name = "Test Script", params = parameters},
    {
        name = "Reverb",
        params = {{name = "Mix", type = "integer", min = 0, max = 100,
                   current = 25, default = 0}}
    }
}

local midi = {
    isAvailable = function() return true end,
    sendMessage = function(...)
        midiMessages[#midiMessages + 1] = {...}
    end
}

local api = nt_api.create({
    display = display,
    helpers = helpers,
    getScript = function() return script end,
    getScriptParameters = function() return parameters end,
    getAlgorithms = function() return algorithms end,
    getBusVoltages = function() return {[1] = 1.25, [28] = -2.5} end,
    getTime = function() return 8 end,
    getMidiHandler = function() return midi end,
    sendI2CCommand = function(address, bytes)
        i2cCommands[#i2cCommands + 1] = {address, bytes}
    end
})

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message,
                            tostring(expected), tostring(actual)), 2)
    end
end

local documentedFunctions = {
    "drawAlgorithmUI", "drawBox", "drawCircle", "drawLine",
    "drawParameterLine", "drawRectangle", "drawSmoothCircle",
    "drawSmoothLine", "drawStandardParameterLine", "drawText",
    "drawTinyText", "exit", "findAlgorithm", "findParameter",
    "focusParameter", "getAlgorithmCount", "getAlgorithmName",
    "getBusVoltage", "getCpuCycleCount", "getCurrentAlgorithm",
    "getCurrentParameter", "getFirmwareVersion", "getParameter",
    "getParameterCount", "getParameterName", "sendI2CCommand",
    "sendI2CGetter", "sendMIDI", "setDisplayMode", "setParameter",
    "setParameterNormalized", "standardPot1Turn", "standardPot2Turn",
    "standardPot3Turn"
}
for _, name in ipairs(documentedFunctions) do
    assertEqual(type(api[name]), "function", name .. " availability")
end

assertEqual(api.getAlgorithmCount(), 2, "algorithm count")
assertEqual(api.getAlgorithmName(1), "Reverb", "algorithm name")
assertEqual(api.findAlgorithm("Reverb"), 1, "find algorithm")
assertEqual(api.findParameter(0, "Speed"), 2, "script parameter offset")
local mode1, mode2 = api.findParameter(0, "Mode")
assertEqual(mode1, 3, "first prefixed parameter")
assertEqual(mode2, 4, "second prefixed parameter")

assertEqual(api.getParameter(0, 2), 5, "scaled parameter read")
api.setParameter(0, 2, 7.5, false)
assertEqual(script.parameters[1], 7.5, "scaled parameter write")
api.setParameterNormalized(0, 2, 0.25)
assertEqual(script.parameters[1], 2.5, "normalized parameter write")
assertEqual(api.getCurrentParameter(0), 2, "parameter focus")

assertEqual(api.getBusVoltage(0, 0), 1.25, "first bus voltage")
assertEqual(api.getBusVoltage(0, 27), -2.5, "last bus voltage")
assertEqual(api.getCpuCycleCount(), 505032704, "32-bit cycle counter wrap")
local major, minor, point, version = api.getFirmwareVersion()
assertEqual(major, 1, "firmware major")
assertEqual(minor, 17, "firmware minor")
assertEqual(point, 0, "firmware point")
assertEqual(version, "1.17.0 (emulated)", "firmware string")

api.sendI2CCommand(0x32, 0x46, 7, 0, 2)
api.sendI2CCommand(0x32, {0x46, 7, 0, 2})
assertEqual(#i2cCommands, 2, "both I2C command forms")
local response = api.sendI2CGetter(0x32, 3, {0x48, 7})
assertEqual(#response, 3, "I2C getter response length")
assertEqual(response[1], 0, "emulated I2C response")

api.sendMIDI(0x4, 0x90, 48, 127)
assertEqual(midiMessages[1][1], 0x90, "MIDI status")
assertEqual(midiMessages[1][3], 127, "MIDI velocity")
api.setDisplayMode("meters")
api.exit()
assertEqual(modes[1], "meters", "display mode")
assertEqual(modes[2], "algorithm", "UI exit mode")

api.drawStandardParameterLine()
api.drawAlgorithmUI(1)
assertEqual(#drawn, 2, "SDK drawing helpers")
assertEqual(drawn[1][3], "Speed: 2.5", "focused parameter line")

require("modules.constants")
local documentedConstants = {
    "kNone", "kDb", "kDb_minInf", "kPercent", "kHz", "kSemitones",
    "kCents", "kMs", "kSeconds", "kFrames", "kMIDINote",
    "kMillivolts", "kVolts", "kBPM", "kBy10", "kBy100", "kBy1000"
}
for _, name in ipairs(documentedConstants) do
    if _G[name] == nil then error(name .. " is missing", 2) end
end

local signalProcessor = require("modules.signal_processor")
local currentOutputs = {}
signalProcessor.init({currentOutputs = currentOutputs})
signalProcessor.updateOutputs({[2] = 5.5}, {[2] = 1})
assertEqual(currentOutputs[1], 5.5, "sparse output update")

print("NT Lua 1.17 API conformance tests passed")
