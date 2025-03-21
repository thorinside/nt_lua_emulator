-- helpers.lua
local helpers = {}

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
        else
            -- Numeric parameter
            entry.name = p[1] or ("Param " .. i)
            entry.min = p[2] or 0
            entry.max = p[3] or 127
            entry.default = p[4] or entry.min
            entry.unit = p[5] or "kNone"
            entry.values = nil -- Explicitly set to nil for non-enum parameters

            if p[6] then
                -- Float parameter with scale: { name, min, max, default, unit, scale }
                entry.type = "float"
                entry.scale = p[6] -- kBy10, kBy100, or kBy1000
                -- Store the display values (scaled up)
                entry.displayMin = entry.min
                entry.displayMax = entry.max
                entry.displayDefault = entry.default
                -- Store the actual values (scaled down)
                entry.min = entry.min / entry.scale
                entry.max = entry.max / entry.scale
                entry.default = entry.default / entry.scale
            else
                -- Integer parameter: { name, min, max, default, unit }
                entry.type = "integer"
                entry.scale = 1
            end

            -- For scaled parameters, set current to displayDefault (UI value)
            -- For non-scaled parameters, set current to default
            if entry.type == "float" and entry.scale ~= 1 then
                entry.current = entry.displayDefault
            else
                entry.current = entry.default
            end

            -- Log parameter parsing for debugging
            print(string.format(
                      "Parsed parameter %d: %s (type=%s, min=%.3f, max=%.3f, default=%.3f, unit=%s, scale=%s)",
                      i, entry.name, entry.type, entry.min, entry.max,
                      entry.default, entry.unit, tostring(entry.scale)))
        end
        scriptParameters[i] = entry
    end
    return scriptParameters
end

-- Updates the script's parameters table from the parsed parameters
function helpers.updateScriptParameters(scriptParameters, script)
    script.parameters = {}
    for i, sp in ipairs(scriptParameters) do
        if sp.type == "float" then
            -- For float parameters, we need to scale down by the scale factor
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
        print("Script parameter values:")
        for i, value in ipairs(script.parameters) do
            print("Parameter " .. i .. ": " .. tostring(value))
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

return helpers
