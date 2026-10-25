-- helpers.lua
local helpers = {}
local debug_utils = require("modules.debug_utils")

function helpers.voltageToColor(v)
    if v < 0 then
        local blue = math.min(1, -v / 10)
        return 0, 0, blue
    else
        local red = math.min(1, v / 10)
        return red, 0, 0
    end
end

-- Parses a table of parameter definitions from the script's init function
-- Returns a structured table of parameters
function helpers.parseScriptParameters(paramsTable)
    local scriptParameters = {}
    for i, p in ipairs(paramsTable) do
        local entry = {}
        if type(p[2]) == "table" then
            -- Enum parameter: { name, enum_values[], default_index }
            entry.type = "enum"
            entry.name = p[1] or ("Param " .. i)
            entry.values = p[2] or {"Default"} -- Ensure values is never nil
            entry.current = p[3] or 1
            if entry.current < 1 then entry.current = 1 end
            if entry.current > #entry.values then
                entry.current = #entry.values
            end
            -- Set min/max for enum types
            entry.min = 1
            entry.max = #entry.values
            entry.default = entry.current
        else
            -- Numeric parameter
            entry.name = p[1] or ("Param " .. i)
            entry.min = p[2] or 0
            entry.max = p[3] or 127
            entry.default = p[4] or entry.min
            entry.unit = p[5] or "kNone"

            if p[6] then
                -- Float parameter with scale: { name, min, max, default, unit, scale }
                entry.type = "float"
                entry.scale = p[6] -- kBy10, kBy100, or kBy1000
                -- Store the display values (unscaled)
                entry.displayMin = entry.min
                entry.displayMax = entry.max
                entry.displayDefault = entry.default
                -- Store the actual values (unscaled)
                entry.min = entry.min
                entry.max = entry.max
                entry.default = entry.default
            else
                -- Integer parameter: { name, min, max, default, unit }
                entry.type = "integer"
                entry.scale = 1
            end

            -- Set current to default (unscaled value)
            entry.current = entry.default
        end

        -- Log parameter parsing for debugging
        debug_utils.debugLog(string.format(
                                 "Parsed parameter %d: %s (type=%s, min=%.3f, max=%.3f, default=%.3f, unit=%s, scale=%s)",
                                 i, entry.name, entry.type, entry.min or 0,
                                 entry.max or 127, entry.default or 0,
                                 entry.unit or "kNone",
                                 tostring(entry.scale or 1)))

        scriptParameters[i] = entry
    end
    return scriptParameters
end

-- Updates the script's parameters table from the parsed parameters
function helpers.updateScriptParameters(scriptParameters, script)
    script.parameters = {}
    for i, sp in ipairs(scriptParameters) do
        if sp.type == "float" and sp.scale then
            -- For float parameters, we need to scale down for the script
            script.parameters[i] = sp.current / sp.scale
        elseif sp.type == "integer" then
            -- For integer parameters, ensure we're passing integers
            script.parameters[i] = math.floor(sp.current + 0.5)
        else
            -- For enum parameters, pass the current index
            script.parameters[i] = sp.current
        end
    end

    -- Add debugging information for parameters
    if script.paramDebug == nil then
        script.paramDebug = true
        debug_utils.debugLog("Script parameter values:")
        for i, value in ipairs(script.parameters) do
            debug_utils.debugLog("Parameter " .. i .. ": " .. tostring(value))
        end
    end
end

-- Returns a friendly name for an input given its index
function helpers.getInputName(script, i)
    if script.inputNames and script.inputNames[i] then
        return script.inputNames[i]
    else
        if type(script.inputs) == "table" then
            local t = script.inputs[i] or "CV"
            return "In " .. i .. " (" .. tostring(t) .. ")"
        else
            return "In " .. i
        end
    end
end

-- Returns a friendly name for an output given its index
function helpers.getOutputName(script, i)
    if script.outputNames and script.outputNames[i] then
        return script.outputNames[i]
    else
        if type(script.outputs) == "table" then
            local t = script.outputs[i] or "CV"
            return "Out " .. i .. " (" .. tostring(t) .. ")"
        else
            return "Out " .. i
        end
    end
end

-- Fit text without byte-splitting UTF-8 or unbounded trimming loops.
local function boundaries(text)
    local ends = {0}
    for i = 2, #text do
        local byte = text:byte(i)
        if byte < 128 or byte >= 192 then ends[#ends + 1] = i - 1 end
    end
    if #text > 0 then ends[#ends + 1] = #text end
    return ends
end
local function fit(text, font, width, suffix)
    local ends = boundaries(text)
    if font:getWidth(suffix) > width then suffix = "" end
    local low, high = 1, #ends
    while low < high do
        local mid = math.ceil((low + high) / 2)
        if font:getWidth(text:sub(1, ends[mid]) .. suffix) <= width then low = mid
        else high = mid - 1 end
    end
    return text:sub(1, ends[low]) .. suffix
end
function helpers.wrapAndEllipsizeText(text, font, maxWidth, maxLines)
    if maxWidth <= 0 or maxLines < 1 then return {} end
    text = tostring(text or "")
    if font:getWidth(text) <= maxWidth then return {text} end
    local words, lines = {}, {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local current = ""
    for i, word in ipairs(words) do
        local candidate = current == "" and word or current .. " " .. word
        if font:getWidth(candidate) <= maxWidth then
            current = candidate
        elseif current ~= "" then
            if #lines + 1 >= maxLines then
                lines[#lines + 1] = fit(current, font, maxWidth, "...")
                return lines
            end
            lines[#lines + 1] = current
            current = word
        else current = word end
        if font:getWidth(current) > maxWidth then
            lines[#lines + 1] = fit(current, font, maxWidth, "...")
            current = ""
            if #lines >= maxLines then return lines end
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

return helpers
