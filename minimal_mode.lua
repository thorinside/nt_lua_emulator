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
local uiFont = nil -- Font for UI elements
local onParameterChange = nil -- Callback function for parameter changes
local helpTextAlpha = 1.0 -- Alpha value for help text
local helpTextTimer = 0 -- Timer for help text fade
local HELP_TEXT_DURATION = 10 -- Duration in seconds before fade starts

-- Add key repeat state variables at the top with other state variables
local keyRepeatState = {
    active = false,
    key = nil,
    startTime = 0,
    lastRepeatTime = 0,
    initialDelay = 0.5, -- Initial delay before repeat starts (in seconds)
    repeatRate = 0.05, -- Time between repeats (in seconds)
    queue = nil -- Single-element queue for the next key event
}

-- Initialize the module
function MinimalMode.init(displayModule, params, callback)
    display = displayModule
    scriptParameters = params
    currentParameter = 1
    isActive = false
    onParameterChange = callback

    local fontSuccess, fontErr = pcall(function()
        uiFont = love.graphics.newFont("fonts/Gidole-Regular.ttf", 12)
    end)

    if not fontSuccess then
        -- Fall back to default font
        uiFont = love.graphics.newFont(10)
    end
end

-- Activate minimal mode
function MinimalMode.activate()
    isActive = true
    currentParameter = 1
    helpTextAlpha = 1.0
    helpTextTimer = 0
end

-- Deactivate minimal mode
function MinimalMode.deactivate() isActive = false end

-- Get active state
function MinimalMode.isActive() return isActive end

-- Set current parameters
function MinimalMode.setParameters(params) scriptParameters = params end

-- Set error message to display
function MinimalMode.setError(err) errorMessage = err end

-- Add helper function to handle parameter value display and scaling
local function getDisplayValue(param)
    -- Return the unscaled value directly since we're storing unscaled values
    return param.current
end

-- Add helper function to handle parameter value changes with scaling
local function adjustParameterValue(param, change)
    local oldValue = param.current
    local newValue = oldValue

    if param.type == "integer" then
        newValue = math.min(param.max, math.max(param.min, oldValue + change))
    elseif param.type == "float" then
        -- Apply change directly to unscaled value
        newValue = math.min(param.max, math.max(param.min, oldValue + change))
    elseif param.type == "enum" then
        local newIndex = oldValue + change
        if newIndex >= 1 and newIndex <= #param.values then
            newValue = newIndex
        end
    end

    return newValue
end

-- Modify handleKeyPress to use the new helper functions
local function handleKeyPress(key)
    if not scriptParameters or #scriptParameters == 0 then return end

    if key == "up" or key == "down" then
        -- Handle parameter value changes
        local param = scriptParameters[currentParameter]
        if param then
            local change
            if param.type == "integer" then
                change = (key == "up") and 1 or -1
            elseif param.type == "float" then
                -- Use unscaled change values
                if param.scale == kBy10 then
                    change = (key == "up") and 1.0 or -1.0
                elseif param.scale == kBy100 then
                    change = (key == "up") and 1.0 or -1.0
                elseif param.scale == kBy1000 then
                    change = (key == "up") and 1.0 or -1.0
                else
                    change = (key == "up") and 0.1 or -0.1
                end
            elseif param.type == "enum" then
                change = (key == "up") and 1 or -1
            end

            local newValue = adjustParameterValue(param, change)

            -- Only trigger callback if value actually changed
            if newValue ~= param.current then
                param.current = newValue
                if onParameterChange then
                    onParameterChange(currentParameter, newValue)
                end
            end
        end
    elseif key == "left" or key == "right" then
        -- Handle parameter navigation
        local change = (key == "right") and 1 or -1
        local newIndex = currentParameter + change
        if newIndex >= 1 and newIndex <= #scriptParameters then
            currentParameter = newIndex
        end
    end
end

-- Handle keypressed events in minimal mode
function MinimalMode.keypressed(key)
    -- Handle F1 to exit minimal mode
    if key == "f1" then
        MinimalMode.deactivate()
        return true
    end

    -- Handle arrow keys for parameter navigation and editing
    if key == "up" or key == "down" or key == "left" or key == "right" then
        -- Initialize key repeat state
        keyRepeatState.active = true
        keyRepeatState.key = key
        keyRepeatState.startTime = love.timer.getTime()
        keyRepeatState.lastRepeatTime = keyRepeatState.startTime
        keyRepeatState.queue = key

        -- Handle the initial key press immediately
        handleKeyPress(key)
        return true
    end

    return false
end

-- Handle keyreleased events
function MinimalMode.keyreleased(key)
    if key == keyRepeatState.key then
        keyRepeatState.active = false
        keyRepeatState.key = nil
        keyRepeatState.queue = nil
    end
end

-- Modify update to handle key repeat and help text fade
function MinimalMode.update(dt)
    -- Update key repeat if active
    if keyRepeatState.active then
        local currentTime = love.timer.getTime()
        local elapsedTime = currentTime - keyRepeatState.startTime
        local timeSinceLastRepeat = currentTime - keyRepeatState.lastRepeatTime

        -- Check if we should start repeating
        if elapsedTime >= keyRepeatState.initialDelay then
            -- Check if it's time for the next repeat
            if timeSinceLastRepeat >= keyRepeatState.repeatRate then
                -- Process the queued key event
                if keyRepeatState.queue then
                    handleKeyPress(keyRepeatState.queue)
                    keyRepeatState.lastRepeatTime = currentTime
                end
            end
        end
    end

    -- Update help text fade
    helpTextTimer = helpTextTimer + dt
    if helpTextTimer >= HELP_TEXT_DURATION then
        helpTextAlpha = math.max(0, helpTextAlpha - dt)
    end

    -- Update error message fade
    if errorMessage then
        errorAlpha = math.max(0, errorAlpha - dt)
        if errorAlpha == 0 then errorMessage = nil end
    end
end

-- Draw minimal UI
function MinimalMode.draw()
    if not isActive then return end

    -- Check if display module is available
    if not display then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.print("ERROR: Display module not initialized", 10, 10)
        -- Reset color before returning
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Get display config
    local config = display.getConfig()
    if not config then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics
            .print("ERROR: Display configuration not available", 10, 10)
        -- Reset color before returning
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local displayW = config.width * config.scaling
    local displayH = config.height * config.scaling

    -- Draw parameter info at the top of the display
    if scriptParameters and currentParameter <= #scriptParameters then
        local param = scriptParameters[currentParameter]

        -- Use teal color (0, 128/255, 128/255 is a nice teal)
        love.graphics.setColor(0, 0.7, 0.7, 1)
        local paramName = param.name or "Parameter " .. currentParameter
        local paramValue = getDisplayValue(param)

        -- Format value based on type
        local valueStr = tostring(paramValue)
        if param.type == "enum" and param.values and param.current <=
            #param.values then
            valueStr = param.values[param.current]
        elseif param.type == "float" then
            valueStr = string.format("%.2f", paramValue)
        end

        -- Use the custom font for UI text
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(uiFont)

        -- Draw parameter info
        love.graphics.printf(paramName .. ": " .. valueStr, 5, 3, displayW - 10,
                             "left")

        -- Draw navigation hint with Unicode arrows and fade (also in teal)
        love.graphics.setColor(0, 0.7, 0.7, helpTextAlpha)
        love.graphics.printf("← → to select  ↑ ↓ to adjust", 5, 3,
                             displayW - 10, "right")

        -- Restore previous font
        love.graphics.setFont(prevFont)
    end

    -- Display error if needed
    if errorMessage then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 10, 10, displayW - 20, 40)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle("line", 10, 10, displayW - 20, 40)
        love.graphics.setColor(1, 1, 1, 1)

        -- Use the custom font for error message
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(uiFont)

        love.graphics.print("Script error (Press F1 to exit minimal mode)", 10,
                            12)
        love.graphics.print(tostring(errorMessage):sub(1, 40), 10, 28)

        -- Restore previous font
        love.graphics.setFont(prevFont)
    end

    -- Reset color to white when done
    love.graphics.setColor(1, 1, 1, 1)
end

return MinimalMode
