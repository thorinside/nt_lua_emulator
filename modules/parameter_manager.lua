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

    -- Remove the automation connection
    parameterAutomation[paramIndex] = nil

    -- Clear the base value
    scriptParameters[paramIndex].baseValue = nil

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

    -- Update the script's parameters
    M.updateScriptParameters()

    return true
end

-- Update all automated parameters based on input values
function M.updateAutomatedParameters(currentInputs, inputPolarity)
    for paramIndex, inputIndex in pairs(parameterAutomation) do
        local sp = scriptParameters[paramIndex]
        local inputValue = currentInputs[inputIndex] or 0

        -- Store base value if not already stored when connecting the parameter
        if sp and not sp.baseValue then sp.baseValue = sp.current end

        if sp and (sp.type == "integer" or sp.type == "float") then
            -- First normalize the CV input to 0-1 range
            local normalizedCV
            if inputPolarity[inputIndex] == kBipolar then
                -- Convert -5V to +5V range to -0.5 to +0.5 range
                normalizedCV = inputValue / 10.0 -- -0.5 to +0.5
            else
                -- Convert 0V to +10V range to 0 to 1 range
                normalizedCV = inputValue / 10.0 -- 0 to 1
            end

            -- Calculate parameter range (using unscaled values)
            local paramRange = sp.max - sp.min

            -- Apply the normalized CV to the parameter range
            local offset = normalizedCV * paramRange

            -- Add offset to base value
            local newValue = sp.baseValue + offset

            -- For integer parameters, round to nearest whole number
            if sp.type == "integer" then
                newValue = math.floor(newValue + 0.5)
            end

            -- Ensure value is within bounds (using unscaled values)
            sp.current = math.max(sp.min, math.min(sp.max, newValue))

        elseif sp and sp.type == "enum" then
            -- For enum parameters, normalize CV to control enum indices
            local valueCount = #sp.values

            -- First normalize the CV input
            local normalizedCV
            if inputPolarity[inputIndex] == kBipolar then
                -- Convert -5V to +5V range to -0.5 to +0.5 range
                normalizedCV = inputValue / 10.0 -- -0.5 to +0.5
            else
                -- Convert 0V to +10V range to 0 to 1 range
                normalizedCV = inputValue / 10.0 -- 0 to 1
            end

            -- Scale normalized CV to enum range and add to base index
            local offset = math.floor(normalizedCV * valueCount + 0.5)
            local valueIndex = sp.baseValue + offset

            -- Ensure the index is valid
            valueIndex = math.max(1, math.min(valueCount, valueIndex))
            sp.current = valueIndex
        end
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
