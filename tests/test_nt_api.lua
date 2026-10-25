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
    getBusVoltages = function() return {[1] = 1.25, [64] = -2.5} end,
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
    "getParameterCount", "getParameterInfo", "getParameterName", "sendI2CCommand",
    "sendI2CGetter", "sendMIDI", "setDisplayMode", "setParameter",
    "setParameterNormalized", "standardPot1Turn", "standardPot2Turn",
    "standardPot3Turn"
}
for _, name in ipairs(documentedFunctions) do
    assertEqual(type(api[name]), "function", name .. " availability")
end

assertEqual(api.getAlgorithmCount(), 2, "algorithm count")
assertEqual(api.getCurrentAlgorithm(), 1, "initial algorithm is one-based")
assertEqual(api.getAlgorithmName(0), nil, "zero is not an algorithm index")
assertEqual(api.getAlgorithmName(1.5), nil, "fractional index is invalid")
assertEqual(api.findAlgorithm("Test Script"), 1, "loaded script index")
assertEqual(api.getAlgorithmName(2), "Reverb", "algorithm name")
assertEqual(api.findAlgorithm("Reverb"), 2, "find algorithm")
assertEqual(api.findParameter(1, "Speed"), 2, "script parameter offset")
local mode1, mode2 = api.findParameter(1, "Mode")
assertEqual(mode1, 3, "first prefixed parameter")
assertEqual(mode2, 4, "second prefixed parameter")

local info = api.getParameterInfo(1, api.findParameter(1, "Speed"))
assertEqual(info.name, "Speed", "metadata uses global script parameter index")
assertEqual(info.min, 0, "raw minimum")
assertEqual(info.max, 100, "raw maximum")
assertEqual(info.def, 50, "raw default")
assertEqual(info.unit, 0, "default unit")
assertEqual(info.scaling, 1, "firmware scaling code for kBy10")
assertEqual(#info.enumStrings, 0, "numeric enum strings")
assertEqual(api.getParameterInfo(1, 1), nil, "unmodeled system parameter")
assertEqual(api.getParameterInfo(99, 1), nil, "invalid algorithm")
assertEqual(api.getParameterInfo(2, 99), nil, "invalid parameter")
assertEqual(api.getParameterInfo(nil, nil), nil, "missing indices")
assertEqual(api.getParameterInfo(2, "1"), nil, "invalid index type")
assertEqual(api.getParameterInfo(1.5, 1), nil, "fractional algorithm")
assertEqual(api.getParameterInfo(2, 0), nil, "zero parameter index")
assertEqual(api.getParameterInfo(2, 1).name, "Mix", "other algorithm metadata")

require("modules.constants")
local metadataParameters = helpers.parseScriptParameters({
    {"Voltage", -100, 100, 0, kVolts, kBy100},
    {"Level", -6000, 0, -1200, kDb, kBy1000},
    {"Mode", {"Off", "On"}, 1},
    {"Amount", 0, 100, 25, kPercent}
})
local metadataApi = nt_api.create({
    display = display,
    helpers = helpers,
    getAlgorithms = function()
        return {{name = "Script"}, {name = "Bypass test", params = {
            {name = "Bypass", min = 0, max = 1, def = 0, unit = 1,
             scaling = 0, enumStrings = {"Off", "On"}}
        }}}
    end,
    getScriptParameters = function() return metadataParameters end
})
local voltage = metadataApi.getParameterInfo(1, 1)
assertEqual(voltage.unit, 13, "firmware voltage unit")
assertEqual(voltage.scaling, 2, "firmware scaling code for kBy100")
assertEqual(voltage.def, 0, "zero default")
local level = metadataApi.getParameterInfo(1, 2)
assertEqual(level.unit, 2, "firmware dB unit")
assertEqual(level.scaling, 3, "firmware scaling code for kBy1000")
local mode = metadataApi.getParameterInfo(1, 3)
assertEqual(mode.unit, 1, "enum unit")
assertEqual(mode.enumStrings[1], "Off", "first enum string")
assertEqual(mode.enumStrings[2], "On", "second enum string")
mode.enumStrings[1] = "Changed"
assertEqual(metadataApi.getParameterInfo(1, 3).enumStrings[1], "Off",
            "metadata does not expose mutable enum storage")
assertEqual(metadataApi.getParameterInfo(1, 4).unit, 4, "firmware percent unit")
local bypass = metadataApi.getParameterInfo(2, 1)
assertEqual(bypass.name, "Bypass", "native metadata name")
assertEqual(bypass.unit, 1, "native enum metadata")
assertEqual(bypass.def, 0, "native default metadata")
assertEqual(bypass.enumStrings[1], "Off", "native enum strings")

assertEqual(api.getParameter(1, 2), 5, "scaled parameter read")
api.setParameter(1, 2, 7.5, false)
assertEqual(script.parameters[1], 7.5, "scaled parameter write")
api.setParameterNormalized(1, 2, 0.25)
assertEqual(script.parameters[1], 2.5, "normalized parameter write")
assertEqual(api.getCurrentParameter(1), 2, "parameter focus")

assertEqual(api.getBusVoltage(0, 0), 1.25, "first bus voltage")
assertEqual(api.getBusVoltage(0, 63), -2.5, "last bus voltage")
assertEqual(api.getBusVoltage(0, 64), 0.0, "out-of-range bus voltage")
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
api.drawAlgorithmUI(2)
assertEqual(#drawn, 3, "SDK drawing helpers")
assertEqual(drawn[2][3], "Reverb", "algorithm parameter view heading")
assertEqual(drawn[3][3], "> Mix: 25", "algorithm parameter view value")
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
