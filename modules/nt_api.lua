-- nt_api.lua
-- Disting NT Lua 1.17 global API compatibility layer.
local M = {}

local unpackValues = table.unpack or unpack
local UINT32 = 4294967296

-- Firmware metadata codes differ from the emulator's script-facing constants.
local unitCodes = {
    none = 0, kNone = 0, dB = 2, dB_minInf = 3, percent = 4,
    Hz = 5, semitones = 6, cents = 7, ms = 8, seconds = 9,
    frames = 10, midi_note = 11, millivolts = 12, bpm = 14
}
local scalingCodes = {[1] = 0, [10] = 1, [100] = 2, [1000] = 3}

local function integer(value)
    if type(value) ~= "number" then return nil end
    return math.floor(value)
end

local function collectBytes(firstIndex, ...)
    local args = {...}
    local bytes = {}
    if type(args[firstIndex]) == "table" then
        for _, value in ipairs(args[firstIndex]) do bytes[#bytes + 1] = value end
    else
        for i = firstIndex, #args do bytes[#bytes + 1] = args[i] end
    end
    return bytes
end

local function validBytes(bytes)
    for _, value in ipairs(bytes) do
        if integer(value) ~= value or value < 0 or value > 255 then return false end
    end
    return true
end

function M.create(options)
    local display = assert(options.display, "display is required")
    local helpers = assert(options.helpers, "helpers is required")
    local currentAlgorithm = 0
    local currentParameters = {}
    local firmware = options.firmwareVersion or {1, 17, 0, "1.17.0 (emulated)"}

    local function script()
        return options.getScript and options.getScript() or nil
    end

    local function scriptParameters()
        return options.getScriptParameters and options.getScriptParameters() or {}
    end

    local function algorithms()
        return options.getAlgorithms and options.getAlgorithms() or {}
    end

    local function algorithmAt(index)
        index = integer(index)
        if not index then return nil end
        return algorithms()[index + 1]
    end

    local function parameterAt(algorithmIndex, parameterIndex, globalIndex)
        local algorithm = algorithmAt(algorithmIndex)
        if not algorithm then return nil end

        if algorithmIndex == 0 then
            local loadedScript = script()
            local offset = loadedScript and (loadedScript.parameterOffset or 1) or 0
            if globalIndex and parameterIndex <= offset then
                return algorithm.systemParams and algorithm.systemParams[parameterIndex],
                       parameterIndex, true
            end
            local index = globalIndex and parameterIndex - offset or parameterIndex + 1
            return scriptParameters()[index], index
        end

        local index = globalIndex and parameterIndex or parameterIndex + 1
        return algorithm.params and algorithm.params[index] or nil, index
    end

    local api = display.createDrawingEnvironment()

    function api.getAlgorithmCount()
        return #algorithms()
    end

    function api.getAlgorithmName(index)
        local algorithm = algorithmAt(index)
        return algorithm and algorithm.name or nil
    end

    function api.findAlgorithm(name)
        if type(name) ~= "string" then return nil end
        local matches = {}
        for index, algorithm in ipairs(algorithms()) do
            if algorithm.name == name then matches[#matches + 1] = index - 1 end
        end
        return unpackValues(matches)
    end

    function api.getCurrentAlgorithm()
        return currentAlgorithm
    end

    function api.getParameterCount(algorithmIndex)
        local algorithm = algorithmAt(algorithmIndex)
        if not algorithm then return nil end
        if algorithmIndex == 0 then
            return #(algorithm.systemParams or {}) + #scriptParameters()
        end
        return #(algorithm.params or {})
    end

    function api.getParameterName(algorithmIndex, parameterIndex)
        local parameter = parameterAt(algorithmIndex, parameterIndex, true)
        return parameter and parameter.name or nil
    end

    function api.getParameterInfo(algorithmIndex, parameterIndex)
        if integer(algorithmIndex) ~= algorithmIndex or
            integer(parameterIndex) ~= parameterIndex or
            algorithmIndex == nil or parameterIndex == nil or
            algorithmIndex < 0 or parameterIndex < 1 then return nil end
        local parameter = parameterAt(algorithmIndex, parameterIndex, true)
        if not parameter then return nil end

        local enumStrings = {}
        for i, value in ipairs(parameter.enumStrings or parameter.values or {}) do
            enumStrings[i] = value
        end
        local unit = parameter.unit
        -- kVolts is represented by 1 in the emulator, not firmware unit 13.
        if parameter.type == "enum" or #enumStrings > 0 then
            unit = 1
        elseif unit == 1 and parameter.scaling == nil then
            unit = 13
        elseif type(unit) ~= "number" then
            unit = unitCodes[unit] or 0
        end
        return {
            name = parameter.name,
            min = parameter.min,
            max = parameter.max,
            def = parameter.def or parameter.default or parameter.min,
            unit = unit,
            scaling = parameter.scaling or scalingCodes[parameter.scale or 1] or 0,
            enumStrings = enumStrings
        }
    end

    function api.findParameter(algorithmIndex, name)
        if type(name) ~= "string" or not algorithmAt(algorithmIndex) then return nil end
        local matches = {}
        local params = algorithmIndex == 0 and scriptParameters() or
                           (algorithmAt(algorithmIndex).params or {})
        local loadedScript = script()
        local offset = algorithmIndex == 0 and loadedScript and
                           (loadedScript.parameterOffset or 1) or 0

        if algorithmIndex == 0 then
            for index, parameter in ipairs(algorithmAt(0).systemParams or {}) do
                if parameter.name == name then matches[#matches + 1] = index end
            end
        end
        for index, parameter in ipairs(params) do
            local parameterName = parameter.name
            local baseName = parameterName and parameterName:match("^%d+:(.+)$")
            if parameterName == name or baseName == name then
                matches[#matches + 1] = index + offset
            end
        end
        return unpackValues(matches)
    end

    function api.getCurrentParameter(algorithmIndex)
        if not algorithmAt(algorithmIndex) then return nil end
        local current = currentParameters[algorithmIndex]
        if current ~= nil then return current end
        local loadedScript = script()
        if algorithmIndex == 0 and loadedScript and #scriptParameters() > 0 then
            return (loadedScript.parameterOffset or 1) + 1
        end
        return api.getParameterCount(algorithmIndex) > 0 and 1 or 0
    end

    function api.focusParameter(algorithmIndex, parameterIndex)
        if not algorithmAt(algorithmIndex) then return end
        currentAlgorithm = algorithmIndex
        currentParameters[algorithmIndex] = parameterIndex
    end

    function api.getParameter(algorithmIndex, parameterIndex)
        local parameter, index, system = parameterAt(algorithmIndex, parameterIndex, true)
        if not parameter then return nil end
        if algorithmIndex == 0 and not system then
            local loadedScript = script()
            return loadedScript and loadedScript.parameters and
                       loadedScript.parameters[index] or nil
        end
        local value = parameter.current
        if value == nil then value = parameter.default or parameter.def or parameter.min end
        return value / (10 ^ (parameter.scaling or 0))
    end

    local function setParameterValue(algorithmIndex, parameterIndex, value, normalized)
        local parameter, _, system = parameterAt(algorithmIndex, parameterIndex, true)
        if not parameter or type(value) ~= "number" then return false end

        if normalized then
            value = math.max(0, math.min(1, value))
            value = parameter.min + value * (parameter.max - parameter.min)
        elseif algorithmIndex == 0 and not system and parameter.type == "float" then
            value = value * (parameter.scale or 1)
        else
            value = value * (10 ^ (parameter.scaling or 0))
        end

        value = math.max(parameter.min, math.min(parameter.max, value))
        if parameter.type == "integer" then
            value = math.floor(value + 0.5)
        elseif parameter.type == "enum" then
            value = math.floor(value + 0.5)
        end
        parameter.current = value
        if algorithmIndex == 0 and system and parameter.name == "Bypass" then
            local loadedScript = script()
            if loadedScript then loadedScript._emulatorBypassed = value ~= 0 end
        end

        if algorithmIndex == 0 and not system then
            local loadedScript = script()
            if loadedScript then helpers.updateScriptParameters(scriptParameters(), loadedScript) end
        end
        return true
    end

    function api.setParameter(algorithmIndex, parameterIndex, value, focus)
        if setParameterValue(algorithmIndex, parameterIndex, value, false) and
            focus ~= false then
            api.focusParameter(algorithmIndex, parameterIndex)
        end
    end

    function api.setParameterNormalized(algorithmIndex, parameterIndex, value, focus)
        if setParameterValue(algorithmIndex, parameterIndex, value, true) and
            focus ~= false then
            api.focusParameter(algorithmIndex, parameterIndex)
        end
    end

    function api.getBusVoltage(_, busIndex)
        busIndex = integer(busIndex)
        if not busIndex or busIndex < 0 or busIndex >= 64 then return 0.0 end
        local values = options.getBusVoltages and options.getBusVoltages() or {}
        return values[busIndex + 1] or 0.0
    end

    function api.getCpuCycleCount()
        local seconds = options.getTime and options.getTime() or 0
        return math.floor(seconds * 600000000) % UINT32
    end

    function api.getFirmwareVersion()
        return firmware[1], firmware[2], firmware[3], firmware[4]
    end

    function api.sendI2CCommand(address, ...)
        local bytes = collectBytes(1, ...)
        if integer(address) ~= address or address < 0 or address > 127 or
            not validBytes(bytes) then return end
        if options.sendI2CCommand then options.sendI2CCommand(address, bytes) end
    end

    function api.sendI2CGetter(address, responseLength, ...)
        responseLength = integer(responseLength)
        local bytes = collectBytes(1, ...)
        if integer(address) ~= address or address < 0 or address > 127 or
            not responseLength or responseLength < 0 or not validBytes(bytes) then
            return nil
        end
        if options.sendI2CGetter then
            return options.sendI2CGetter(address, responseLength, bytes)
        end
        local response = {}
        for i = 1, responseLength do response[i] = 0 end
        return response
    end

    function api.sendMIDI(_, ...)
        local bytes = {...}
        if #bytes < 1 or #bytes > 3 or not validBytes(bytes) then return end
        local midi = options.getMidiHandler and options.getMidiHandler() or nil
        if midi and midi.isAvailable and midi.isAvailable() then
            midi.sendMessage(unpackValues(bytes))
        end
    end

    function api.setDisplayMode(mode)
        display.setDisplayMode(mode)
    end

    function api.exit()
        display.setDisplayMode("algorithm")
    end

    function api.drawParameterLine(algorithmIndex, parameterIndex, yOffset)
        local parameter = parameterAt(algorithmIndex, parameterIndex, true)
        local name = parameter and parameter.name or "Parameter"
        local value = api.getParameter(algorithmIndex, parameterIndex)
        local text = value == nil and name or string.format("%s: %s", name, tostring(value))
        display.drawText(1, (yOffset or 0) + 8, text, 15)
    end

    function api.drawStandardParameterLine()
        local algorithmIndex = api.getCurrentAlgorithm()
        api.drawParameterLine(algorithmIndex,
                              api.getCurrentParameter(algorithmIndex), 0)
    end

    function api.drawAlgorithmUI(algorithmIndex)
        display.drawText(128, 36, api.getAlgorithmName(algorithmIndex) or "Algorithm",
                         15, "centre")
    end

    function api.standardPot1Turn(value)
        if options.standardPotTurn then options.standardPotTurn(1, value) end
    end

    function api.standardPot2Turn(value)
        if options.standardPotTurn then options.standardPotTurn(2, value) end
    end

    function api.standardPot3Turn(value)
        if options.standardPotTurn then options.standardPotTurn(3, value) end
    end

    return api
end

return M
