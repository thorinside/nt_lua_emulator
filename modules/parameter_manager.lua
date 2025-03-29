-- parameter_manager.lua
-- Module for handling script parameter management and automation
local M = {} -- Module table

-- Local state variables
local scriptParameters = {}
local parameterAutomation = {} -- Maps parameter index to physical input index

-- Initialize the parameter manager
function M.init(deps)
    -- Store dependencies
    M.helpers = deps.helpers

    return M
end

-- Set the script parameters
function M.setParameters(params, script)
    scriptParameters = params or {}
    M.script = script
    return scriptParameters
end

-- Get the script parameters
function M.getParameters() return scriptParameters end

-- Get parameter automation
function M.getParameterAutomation() return parameterAutomation end

-- Set parameter automation
function M.setParameterAutomation(automation)
    parameterAutomation = automation or {}
end

-- Connect a parameter to a physical input for automation
function M.connectParameterToInput(paramIndex, inputIndex)
    if not scriptParameters[paramIndex] then
        return false, "Parameter index out of range"
    end

    -- Store the current value as the base value before automation
    local param = scriptParameters[paramIndex]
    param.baseValue = param.current

    -- Connect the parameter to the input
    parameterAutomation[paramIndex] = inputIndex

    return true
end

-- Disconnect a parameter from automation
function M.disconnectParameter(paramIndex)
    if not scriptParameters[paramIndex] then
        return false, "Parameter index out of range"
    end

    -- If parameter has a stored base value, restore it
    local param = scriptParameters[paramIndex]
    if param.baseValue then
        param.current = param.baseValue
        param.baseValue = nil
    end

    -- Remove the automation connection
    parameterAutomation[paramIndex] = nil

    return true
end

-- Reset a parameter to its default value
function M.resetParameter(paramIndex)
    if not scriptParameters[paramIndex] or
        not scriptParameters[paramIndex].default then
        return false, "Parameter index out of range or no default value"
    end

    -- Clear any automation
    parameterAutomation[paramIndex] = nil
    scriptParameters[paramIndex].baseValue = nil

    -- Reset to default value
    scriptParameters[paramIndex].current = scriptParameters[paramIndex].default

    -- Update the script's parameters
    M.updateScriptParameters()

    return true
end

-- Update parameter value
function M.updateParameterValue(paramIndex, newValue)
    if not scriptParameters[paramIndex] then
        return false, "Parameter index out of range"
    end

    local param = scriptParameters[paramIndex]

    -- Clamp the value within range based on parameter type
    if param.type == "enum" then
        -- For enum parameters, clamp between 1 and the number of values
        if param.values then
            newValue = math.max(1, math.min(#param.values, newValue))
        end
    else
        -- For numeric parameters (integer, float), use min/max
        newValue = math.max(param.min, math.min(param.max, newValue))

        -- For integer parameters, round to nearest whole number
        if param.type == "integer" then
            newValue = math.floor(newValue + 0.5)
        end
    end

    -- Update the parameter value
    param.current = newValue

    -- If parameter is automated, also update baseValue
    if parameterAutomation[paramIndex] then param.baseValue = newValue end

    -- Update the script's parameters
    M.updateScriptParameters()

    return true
end

-- Update all automated parameters based on input values
function M.updateAutomatedParameters(currentInputs)
    for paramIndex, inputIndex in pairs(parameterAutomation) do
        local sp = scriptParameters[paramIndex]
        if not sp then goto continue end -- Skip if parameter doesn't exist

        -- Get the input voltage (already scaled for physical input)
        local voltage = currentInputs[inputIndex] or 0

        -- Store base value (user-set value) if not already stored when connecting the parameter
        if not sp.baseValue then sp.baseValue = sp.current end
        local baseValue = sp.baseValue

        if sp.type == "integer" or sp.type == "float" then
            -- Calculate parameter range
            local paramRange = sp.max - sp.min

            -- Normalize the voltage by dividing by 12V
            local normalizedVoltage = voltage / 12.0

            local newValue = baseValue + (normalizedVoltage * paramRange)

            -- For integer parameters, round to nearest whole number
            if sp.type == "integer" then
                newValue = math.floor(newValue + 0.5)
            end

            -- Ensure value is within bounds
            sp.current = math.max(sp.min, math.min(sp.max, newValue))

        elseif sp.type == "enum" and sp.values then
            -- For enum parameters
            local valueCount = #sp.values

            -- Normalize the voltage by dividing by 12V
            local normalizedVoltage = voltage / 12.0

            -- Calculate how many steps to move from the base value
            local enumRange = valueCount - 1
            local offset = math.floor(normalizedVoltage * enumRange + 0.5)

            -- Apply offset to base value
            local newIndex = baseValue + offset

            -- Ensure the index is valid
            sp.current = math.max(1, math.min(valueCount, newIndex))
        end

        ::continue::
    end

    -- Update the script's parameters
    M.updateScriptParameters()
end

-- Update script parameters in the script object
function M.updateScriptParameters()
    if scriptParameters and M.script then
        M.helpers.updateScriptParameters(scriptParameters, M.script)
    end
end

-- Get parameter info by index
function M.getParameterInfo(paramIndex)
    if not scriptParameters[paramIndex] then
        return nil, "Parameter index out of range"
    end

    return scriptParameters[paramIndex]
end

-- Check if a parameter is automated
function M.isParameterAutomated(paramIndex)
    return parameterAutomation[paramIndex] ~= nil
end

-- Get input controlling a parameter
function M.getParameterInputIndex(paramIndex)
    return parameterAutomation[paramIndex]
end

return M
