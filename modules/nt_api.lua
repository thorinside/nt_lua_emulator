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
        if type(value) ~= "number" or integer(value) ~= value or
            value < 0 or value > 255 then return false end
    end
    return true
end

function M.create(options)
    local display = assert(options.display, "display is required")
    local helpers = assert(options.helpers, "helpers is required")
    local currentAlgorithm = 1
    local currentParameters = {}
    local displayMode, uiExited = "ui", false
    local virtualI2C = require("modules.virtual_i2c").create()
    local lastValuePot, valuePotTarget
    local pageSize = 6
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
        if type(index) ~= "number" or index ~= integer(index) or index < 1 then return nil end
        return algorithms()[index]
    end

    local function parameterAt(algorithmIndex, parameterIndex, globalIndex)
        local algorithm = algorithmAt(algorithmIndex)
        if not algorithm then return nil end

        if algorithmIndex == 1 then
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
            if algorithm.name == name then matches[#matches + 1] = index end
        end
        return unpackValues(matches)
    end

    function api.getCurrentAlgorithm()
        return currentAlgorithm
    end

    function api.getParameterCount(algorithmIndex)
        local algorithm = algorithmAt(algorithmIndex)
        if not algorithm then return nil end
        if algorithmIndex == 1 then
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
            algorithmIndex < 1 or parameterIndex < 1 then return nil end
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
        local params = algorithmIndex == 1 and scriptParameters() or
                           (algorithmAt(algorithmIndex).params or {})
        local loadedScript = script()
        local offset = algorithmIndex == 1 and loadedScript and
                           (loadedScript.parameterOffset or 1) or 0

        if algorithmIndex == 1 then
            for index, parameter in ipairs(algorithmAt(1).systemParams or {}) do
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
        if algorithmIndex == 1 and loadedScript and #scriptParameters() > 0 then
            return (loadedScript.parameterOffset or 1) + 1
        end
        return api.getParameterCount(algorithmIndex) > 0 and 1 or 0
    end

    function api.focusParameter(algorithmIndex, parameterIndex)
        if not api.getParameterInfo(algorithmIndex, parameterIndex) then return end
        currentAlgorithm = algorithmIndex
        currentParameters[algorithmIndex] = parameterIndex
    end

    function api.getParameter(algorithmIndex, parameterIndex)
        local parameter, index, system = parameterAt(algorithmIndex, parameterIndex, true)
        if not parameter then return nil end
        if algorithmIndex == 1 and not system then
            local loadedScript = script()
            return loadedScript and loadedScript.parameters and
                       loadedScript.parameters[index] or nil
        end
        local value = parameter.current
        if value == nil then value = parameter.default or parameter.def or parameter.min end
        if not parameter.scaling or parameter.scaling == 0 then return value end
        return value / (10 ^ parameter.scaling)
    end

    local function setParameterValue(algorithmIndex, parameterIndex, value, normalized)
        local parameter, _, system = parameterAt(algorithmIndex, parameterIndex, true)
        if not parameter or type(value) ~= "number" or value ~= value or
            math.abs(value) == math.huge then return false end

        if normalized then
            value = math.max(0, math.min(1, value))
            value = parameter.min + value * (parameter.max - parameter.min)
        elseif algorithmIndex == 1 and not system and parameter.type == "float" then
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
        if algorithmIndex == 1 and system and parameter.name == "Bypass" then
            local loadedScript = script()
            if loadedScript then loadedScript._emulatorBypassed = value ~= 0 end
        end

        if algorithmIndex == 1 and not system then
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

    function api.getBusVoltage(algorithmIndex, busIndex)
        if type(algorithmIndex) ~= "number" or algorithmIndex ~= integer(algorithmIndex) or
            algorithmIndex < 0 or algorithmIndex > #algorithms() then return 0.0 end
        if type(busIndex) ~= "number" or busIndex ~= integer(busIndex) or
            busIndex < 0 or busIndex >= 64 then return 0.0 end
        if options.getBusVoltage then return options.getBusVoltage(algorithmIndex, busIndex) or 0.0 end
        local values = options.getBusVoltages and options.getBusVoltages(algorithmIndex) or {}
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
        if type(address) ~= "number" or integer(address) ~= address or
            address < 0 or address > 127 or not validBytes(bytes) then return end
        if options.sendI2CCommand then
            options.sendI2CCommand(address, bytes)
        else
            virtualI2C.sendCommand(address, bytes)
        end
    end

    function api.sendI2CGetter(address, responseLength, ...)
        responseLength = integer(responseLength)
        local bytes = collectBytes(1, ...)
        if type(address) ~= "number" or integer(address) ~= address or
            address < 0 or address > 127 or not responseLength or
            responseLength < 0 or responseLength > 1024 or
            not validBytes(bytes) then
            return nil
        end
        if options.sendI2CGetter then
            return options.sendI2CGetter(address, responseLength, bytes)
        end
        return virtualI2C.get(address, responseLength, bytes)
    end

    function api.sendMIDI(destinations, ...)
        local midi = options.getMidiHandler and options.getMidiHandler() or nil
        if midi and midi.sendToDestinations then
            -- The router validates and records rejected calls as diagnostics too.
            midi.sendToDestinations(destinations, ...)
            return
        end
        local bytes = {...}
        if type(destinations) ~= "number" or integer(destinations) ~= destinations or
            destinations < 1 or destinations > 15 or #bytes < 1 or #bytes > 3 or
            not validBytes(bytes) then return end
        if midi and midi.isAvailable and midi.isAvailable() then
            midi.sendMessage(unpackValues(bytes))
        end
    end

    function api.setDisplayMode(mode)
        local valid = {overview = true, meters = true, parameters = true,
                       ui = true, algorithm = true, menu = true}
        if not valid[mode] then return end
        displayMode = mode
        if mode == "ui" then uiExited = false end
        display.setDisplayMode(mode)
    end

    function api.exit()
        uiExited = true
        api.setDisplayMode("algorithm")
    end

    local unitLabels = {
        [2] = "dB", [3] = "dB", [4] = "%", [5] = "Hz", [6] = "st",
        [7] = "ct", [8] = "ms", [9] = "s", [10] = "frames", [12] = "mV",
        [13] = "V", [14] = "BPM"
    }
    local function formattedValue(algorithmIndex, parameterIndex)
        local info = api.getParameterInfo(algorithmIndex, parameterIndex)
        local value = api.getParameter(algorithmIndex, parameterIndex)
        if not info or value == nil then return "--" end
        if info.unit == 1 then
            return info.enumStrings[value - info.min + 1] or tostring(value)
        end
        local label = info.scaling > 0 and
                          string.format("%." .. info.scaling .. "f", value) or tostring(value)
        local unit = unitLabels[info.unit]
        return unit and (label .. " " .. unit) or label
    end

    function api.drawParameterLine(algorithmIndex, parameterIndex, yOffset)
        local name = api.getParameterName(algorithmIndex, parameterIndex) or "Parameter"
        display.drawText(1, (yOffset or 0) + 8,
                         name .. ": " .. formattedValue(algorithmIndex, parameterIndex), 15)
    end

    function api.drawStandardParameterLine()
        local algorithmIndex = api.getCurrentAlgorithm()
        api.drawParameterLine(algorithmIndex,
                              api.getCurrentParameter(algorithmIndex), 0)
    end

    function api.drawAlgorithmUI(algorithmIndex)
        local name = api.getAlgorithmName(algorithmIndex)
        if not name then return end
        display.drawText(1, 8, name, 15)
        local count = api.getParameterCount(algorithmIndex)
        local focused = api.getCurrentParameter(algorithmIndex)
        if count == 0 then
            display.drawText(1, 24, "No parameters", 8)
            return
        end
        local first = math.floor((focused - 1) / pageSize) * pageSize + 1
        for index = first, math.min(count, first + pageSize - 1) do
            local marker = index == focused and "> " or "  "
            local text = marker .. api.getParameterName(algorithmIndex, index) .. ": " ..
                             formattedValue(algorithmIndex, index)
            display.drawText(1, 17 + (index - first) * 9, text, index == focused and 15 or 8)
        end
    end

    local function potValue(value)
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
            return nil
        end
        return math.max(0, math.min(1, value))
    end
    local function selectIndex(value, count)
        return math.min(count, math.floor(value * count) + 1)
    end

    function api.standardPot1Turn(value)
        if options.standardPotTurn then return options.standardPotTurn(1, value) end
        value = potValue(value)
        local count = api.getParameterCount(currentAlgorithm) or 0
        if not value or count == 0 then return end
        local page = selectIndex(value, math.ceil(count / pageSize)) - 1
        local withinPage = (api.getCurrentParameter(currentAlgorithm) - 1) % pageSize
        api.focusParameter(currentAlgorithm, math.min(count, page * pageSize + withinPage + 1))
    end

    function api.standardPot2Turn(value)
        if options.standardPotTurn then return options.standardPotTurn(2, value) end
        value = potValue(value)
        local count = api.getParameterCount(currentAlgorithm) or 0
        if not value or count == 0 then return end
        local first = math.floor((api.getCurrentParameter(currentAlgorithm) - 1) / pageSize) * pageSize
        api.focusParameter(currentAlgorithm, first + selectIndex(value, math.min(pageSize, count - first)))
    end

    function api.standardPot3Turn(value)
        if options.standardPotTurn then return options.standardPotTurn(3, value) end
        value = potValue(value)
        if not value then return end
        local previous = lastValuePot
        lastValuePot = value
        -- Directional soft takeover: selecting a parameter never causes a jump.
        if previous == nil then return end
        local index = api.getCurrentParameter(currentAlgorithm)
        local info = api.getParameterInfo(currentAlgorithm, index)
        local current = api.getParameter(currentAlgorithm, index)
        if not info or current == nil or info.max == info.min then return end
        if not valuePotTarget or valuePotTarget.algorithm ~= currentAlgorithm or
            valuePotTarget.index ~= index or valuePotTarget.current ~= current then
            valuePotTarget = {algorithm = currentAlgorithm, index = index,
                normalized = (current * 10 ^ info.scaling - info.min) / (info.max - info.min)}
        end
        valuePotTarget.normalized = math.max(0, math.min(1,
            valuePotTarget.normalized + value - previous))
        api.setParameterNormalized(currentAlgorithm, index, valuePotTarget.normalized)
        valuePotTarget.current = api.getParameter(currentAlgorithm, index)
    end

    -- Host runtime hooks are returned separately, not installed as firmware globals.
    local runtime = {}
    function runtime.drawDisplayMode()
        local loadedScript = script()
        if displayMode == "ui" or (displayMode == "algorithm" and not uiExited) then
            if loadedScript and loadedScript.draw then return false end
            api.drawAlgorithmUI(currentAlgorithm)
        elseif displayMode == "parameters" or displayMode == "algorithm" then
            api.drawAlgorithmUI(currentAlgorithm)
        elseif displayMode == "overview" then
            display.drawText(1, 8, "Preset (simulated)", 15)
            local first = math.floor((currentAlgorithm - 1) / 5) * 5 + 1
            local preset = algorithms()
            for index = first, math.min(#preset, first + 4) do
                display.drawText(1, 19 + (index - first) * 10,
                                 (index == currentAlgorithm and "> " or "  ") .. preset[index].name, 12)
            end
        elseif displayMode == "meters" then
            display.drawText(1, 8, "Connected buses (V)", 15)
            local draw = display.drawTinyText or display.drawText
            for bus = 1, 20 do
                local label = bus <= 12 and ("I" .. bus) or ("O" .. (bus - 12))
                local stage = bus <= 12 and 0 or #algorithms()
                draw(1 + ((bus - 1) % 5) * 51, 22 + math.floor((bus - 1) / 5) * 12,
                     string.format("%s %+.2f", label, api.getBusVoltage(stage, bus - 1)), 12)
            end
        elseif displayMode == "menu" then
            display.drawText(1, 8, "Emulator tools", 15)
            display.drawText(1, 22, "F2 Load  F3 MIDI in  F4 MIDI out", 12)
            display.drawText(1, 34, "F4 MIDI routing  F5 MIDI log", 12)
            local history = virtualI2C.getHistory()
            local last = history[#history]
            display.drawText(1, 46, "I2C: virtual register device", 10)
            display.drawText(1, 58, last and string.format("Last %s @ 0x%02X", last.kind, last.address) or
                             "I2C: no traffic yet", 10)
        end
        return true
    end
    function runtime.handlePot(index, value)
        if displayMode == "ui" or (displayMode == "algorithm" and not uiExited) then
            return false
        end
        if displayMode == "overview" and index == 1 then
            value = potValue(value)
            if value and #algorithms() > 0 then
                currentAlgorithm = selectIndex(value, #algorithms())
            end
        else
            local turn = api["standardPot" .. index .. "Turn"]
            if turn then turn(value) end
        end
        return true
    end
    runtime.getI2CHistory = virtualI2C.getHistory

    return api, runtime
end

return M
