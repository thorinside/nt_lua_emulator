-- minimal_mode.lua
-- Implements a minimal mode for the Disting NT Emulator where only the display is shown
-- with parameter information and minimal controls via keyboard.
local MinimalMode = {}

-- State variables
local isActive = false
local display = nil
local scriptParameters = nil
local currentParameter = 1
local errorMessage = nil

-- Initialize the module
function MinimalMode.init(displayModule, params)
    display = displayModule
    scriptParameters = params
    currentParameter = 1
    isActive = false
end

-- Activate minimal mode
function MinimalMode.activate()
    isActive = true
    currentParameter = 1
end

-- Deactivate minimal mode
function MinimalMode.deactivate() isActive = false end

-- Get active state
function MinimalMode.isActive() return isActive end

-- Set current parameters
function MinimalMode.setParameters(params) scriptParameters = params end

-- Set error message to display
function MinimalMode.setError(err) errorMessage = err end

-- Handle keypressed events in minimal mode
function MinimalMode.keypressed(key)
    if not isActive then return false end

    -- Key was handled
    if key == "left" or key == "right" then
        -- Navigate parameters
        local paramCount = 0
        if scriptParameters then paramCount = #scriptParameters end

        if key == "left" then
            currentParameter = currentParameter - 1
            if currentParameter < 1 then
                currentParameter = paramCount
            end
        else
            currentParameter = currentParameter + 1
            if currentParameter > paramCount then
                currentParameter = 1
            end
        end
        return true
    elseif key == "up" or key == "down" then
        -- Adjust parameter value
        if scriptParameters and currentParameter <= #scriptParameters then
            local param = scriptParameters[currentParameter]

            -- Calculate value change based on parameter type
            if param.type == "integer" then
                local change = (key == "up") and 1 or -1
                param.current = math.min(param.max, math.max(param.min,
                                                             param.current +
                                                                 change))
                return true
            elseif param.type == "float" then
                local change = (key == "up") and 0.1 or -0.1
                param.current = math.min(param.max, math.max(param.min,
                                                             param.current +
                                                                 change))
                return true
            elseif param.type == "enum" and param.values then
                local change = (key == "up") and 1 or -1
                param.current = param.current + change
                if param.current > #param.values then
                    param.current = 1
                elseif param.current < 1 then
                    param.current = #param.values
                end
                return true
            end
        end
        return true
    end

    -- Key wasn't handled by minimal mode
    return false
end

-- Handle keyreleased events
function MinimalMode.keyreleased(key)
    -- Nothing to do on key release for now
end

-- Update function
function MinimalMode.update(dt)
    -- Update processing
end

-- Draw minimal UI
function MinimalMode.draw()
    if not isActive then return end

    -- Get display config
    local config = display.getConfig()
    local displayW = config.width * config.scaling
    local displayH = config.height * config.scaling

    -- Draw parameter info at the bottom of the display
    if scriptParameters and currentParameter <= #scriptParameters then
        local param = scriptParameters[currentParameter]
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, displayH - 20, displayW, 20)

        love.graphics.setColor(1, 1, 1, 1)
        local paramName = param.name or "Parameter " .. currentParameter
        local paramValue = param.current

        -- Format value based on type
        local valueStr = tostring(paramValue)
        if param.type == "enum" and param.values and param.current <=
            #param.values then
            valueStr = param.values[param.current]
        elseif param.type == "float" then
            valueStr = string.format("%.2f", paramValue)
        end

        -- Draw parameter info
        love.graphics.printf(paramName .. ": " .. valueStr, 5, displayH - 17,
                             displayW - 10, "left")

        -- Draw navigation hint
        love.graphics.printf("◄ ► to select  ▲ ▼ to adjust", 5,
                             displayH - 17, displayW - 10, "right")
    end

    -- Display error if needed
    if errorMessage then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 10, 10, displayW - 20, 40)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle("line", 10, 10, displayW - 20, 40)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Script error (Press F1 to exit minimal mode)", 10,
                            12)
        love.graphics.print(tostring(errorMessage):sub(1, 40), 10, 28)
    end
end

return MinimalMode
