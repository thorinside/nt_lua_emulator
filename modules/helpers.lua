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

-- Helper function to wrap and ellipsize text
function helpers.wrapAndEllipsizeText(text, font, maxWidth, maxLines)
    -- If the entire text fits in one line, just return it
    if font:getWidth(text) <= maxWidth then return {text} end

    local words = {}
    for word in text:gmatch("%S+") do table.insert(words, word) end

    local lines = {}
    local currentLine = ""
    local currentWidth = 0

    for i, word in ipairs(words) do
        local wordWidth = font:getWidth(word)
        local spaceWidth = font:getWidth(" ")

        -- Handle very long words that exceed maxWidth on their own
        if wordWidth > maxWidth then
            -- If we have something in the current line, add it first
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                if #lines >= maxLines then
                    -- Ellipsize the last line if needed
                    local lastLine = lines[#lines]
                    while font:getWidth(lastLine .. "...") > maxWidth do
                        lastLine = lastLine:sub(1, -2)
                    end
                    lines[#lines] = lastLine .. "..."
                    return lines
                end
                currentLine = ""
                currentWidth = 0
            end

            -- Handle the long word by truncating it
            local truncatedWord = word
            while font:getWidth(truncatedWord) > maxWidth do
                truncatedWord = truncatedWord:sub(1, -2)
            end
            truncatedWord = truncatedWord .. "..."

            table.insert(lines, truncatedWord)
            if #lines >= maxLines then return lines end
        else
            -- Normal word that fits within maxWidth
            if currentLine == "" then
                -- First word on the line
                currentLine = word
                currentWidth = wordWidth
            else
                -- Check if adding this word would exceed maxWidth
                if currentWidth + spaceWidth + wordWidth <= maxWidth then
                    currentLine = currentLine .. " " .. word
                    currentWidth = currentWidth + spaceWidth + wordWidth
                else
                    -- Start a new line
                    table.insert(lines, currentLine)
                    if #lines >= maxLines then
                        -- If we've reached max lines, ellipsize the last line
                        local lastLine = lines[#lines]
                        while font:getWidth(lastLine .. "...") > maxWidth do
                            lastLine = lastLine:sub(1, -2)
                        end
                        lines[#lines] = lastLine .. "..."
                        return lines
                    end
                    currentLine = word
                    currentWidth = wordWidth
                end
            end
        end
    end

    -- Add the last line if there is one
    if currentLine ~= "" then
        table.insert(lines, currentLine)
        if #lines > maxLines then
            -- If we've exceeded max lines, ellipsize the last line
            local lastLine = lines[maxLines]
            while font:getWidth(lastLine .. "...") > maxWidth do
                lastLine = lastLine:sub(1, -2)
            end
            lines[maxLines] = lastLine .. "..."
            -- Remove any extra lines
            for i = maxLines + 1, #lines do lines[i] = nil end
        end
    end

    return lines
end

return helpers
