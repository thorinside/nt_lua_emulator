local controls = {}

-- Constants for control types
local kPot = 1
local kEncoder = 2
local kButton = 3

-- Constants for control positions and sizes
local kPotRadius = 20
local kEncoderRadius = 18
local kButtonRadius = 8
local kPotSpacing = 60
local kButtonSpacing = 30

-- Constants for pot rotation
local kPotStartAngle = (4 / 12) * 2 * math.pi -- 4 o'clock (was 10 o'clock)
local kPotEndAngle = (14 / 12) * 2 * math.pi -- 2 o'clock (was 8 o'clock)
local kPotAngleRange = kPotEndAngle - kPotStartAngle -- Clockwise from 4 to 2

-- Control state
local isActive = false -- Track whether controls are active

-- Control state
local controls = {
    -- Pots (with push function)
    {
        type = kPot,
        x = 0, -- Will be set in layout
        y = 0, -- Will be set in layout
        value = 0, -- 0 to 1 range
        pushed = false,
        name = "pot_1"
    }, {type = kPot, x = 0, y = 0, value = 0, pushed = false, name = "pot_2"},
    {type = kPot, x = 0, y = 0, value = 0, pushed = false, name = "pot_3"},

    -- Encoders (with push function)
    {
        type = kEncoder,
        x = 0,
        y = 0,
        value = 0, -- Accumulated ticks
        pushed = false,
        name = "left_encoder"
    }, {
        type = kEncoder,
        x = 0,
        y = 0,
        value = 0,
        pushed = false,
        name = "right_encoder"
    }, -- Buttons
    {type = kButton, x = 0, y = 0, pushed = false, name = "button_1"},
    {type = kButton, x = 0, y = 0, pushed = false, name = "button_2"},
    {type = kButton, x = 0, y = 0, pushed = false, name = "button_3"},
    {type = kButton, x = 0, y = 0, pushed = false, name = "button_4"}
}

-- Set pot positions based on values returned from setupUi
function controls.setPotPositions(potValues)
    if not potValues then return end

    -- Set pot values for each available pot
    for i = 1, 3 do
        if potValues[i] ~= nil then
            -- Clamp values to 0-1 range
            controls[i].value = math.max(0, math.min(1, potValues[i]))
            print(string.format("[Controls] Set %s position to %.2f",
                                controls[i].name, controls[i].value))
        end
    end
end

-- Layout the controls based on the display area
function controls.layout(displayX, displayY, displayWidth, displayHeight)
    local centerX = displayX + displayWidth / 2
    local startY = displayY + displayHeight + 40 -- Start 40 pixels below display

    -- Position the three pots across the top
    local potY = startY
    local leftPotX = centerX - kPotSpacing
    local rightPotX = centerX + kPotSpacing

    controls[1].x = leftPotX -- Left pot
    controls[1].y = potY
    controls[2].x = centerX -- Center pot
    controls[2].y = potY
    controls[3].x = rightPotX -- Right pot
    controls[3].y = potY

    -- Position encoders below, slightly inset
    local encoderY = potY + kPotRadius * 3
    local encoderInset = kPotSpacing * 0.7

    controls[4].x = centerX - encoderInset -- Left encoder
    controls[4].y = encoderY
    controls[5].x = centerX + encoderInset -- Right encoder
    controls[5].y = encoderY

    -- Position buttons on the sides
    local leftButtonX = leftPotX - kPotRadius * 1.5
    local rightButtonX = rightPotX + kPotRadius * 1.5 + 4 -- Add 4px to right buttons
    local button1Y = potY
    local button2Y = potY + kButtonSpacing
    local button3Y = button2Y
    local button4Y = button1Y

    controls[6].x = leftButtonX - 8 -- Button 1: 8px more to the left
    controls[6].y = button1Y
    controls[7].x = leftButtonX -- Button 2: original position
    controls[7].y = button2Y
    controls[8].x = rightButtonX -- Button 3: 4px right (from rightButtonX adjustment)
    controls[8].y = button3Y
    controls[9].x = rightButtonX + 4 -- Button 4: 4px more to the right
    controls[9].y = button4Y
end

-- Draw all controls
function controls.draw()
    -- Draw each control
    for _, control in ipairs(controls) do
        if control.type == kPot then
            -- Draw pot base (darker gray)
            if control.pushed then
                love.graphics.setColor(0.4, 0.4, 0.4) -- 20% brighter when pushed
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end
            love.graphics.circle("fill", control.x, control.y, kPotRadius)

            -- Draw indicator line (white)
            -- Map 0-1 value to angle range from 07:00 to 17:00
            local angle = kPotStartAngle + (control.value * kPotAngleRange) -- Clockwise rotation
            local lineLength = kPotRadius * 0.8
            local endX = control.x + math.cos(angle) * lineLength
            local endY = control.y + math.sin(angle) * lineLength
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2) -- Make the line more visible
            love.graphics.line(control.x, control.y, endX, endY)

            -- Draw pot rim (lighter gray)
            if control.pushed then
                love.graphics.setColor(0.6, 0.6, 0.6) -- 20% brighter when pushed
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
            end
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", control.x, control.y, kPotRadius)

        elseif control.type == kEncoder then
            -- Draw encoder base (darker gray)
            if control.pushed then
                love.graphics.setColor(0.4, 0.4, 0.4) -- 20% brighter when pushed
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end
            love.graphics.circle("fill", control.x, control.y, kEncoderRadius)

            -- Draw indicator dots around the encoder (white)
            love.graphics.setColor(1, 1, 1)
            local dotCount = 24 -- Number of dots around the encoder
            local currentDot = control.value % dotCount -- Which dot is current
            local dotRadius = 2
            local dotDistance = kEncoderRadius * 0.8

            for i = 0, dotCount - 1 do
                local dotAngle = (i * 2 * math.pi) / dotCount
                local dotX = control.x + math.cos(dotAngle) * dotDistance
                local dotY = control.y + math.sin(dotAngle) * dotDistance

                if i == currentDot then
                    -- Current position dot (larger and brighter)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.circle("fill", dotX, dotY, dotRadius * 1.5)
                else
                    -- Other dots (dimmer)
                    if control.pushed then
                        love.graphics.setColor(0.6, 0.6, 0.6) -- 20% brighter when pushed
                    else
                        love.graphics.setColor(0.4, 0.4, 0.4)
                    end
                    love.graphics.circle("fill", dotX, dotY, dotRadius)
                end
            end

            -- Draw encoder rim (lighter gray)
            if control.pushed then
                love.graphics.setColor(0.6, 0.6, 0.6) -- 20% brighter when pushed
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
            end
            love.graphics.circle("line", control.x, control.y, kEncoderRadius)

        elseif control.type == kButton then
            -- Draw button
            if control.pushed then
                love.graphics.setColor(1, 1, 1) -- White when pushed
            else
                love.graphics.setColor(0.2, 0.2, 0.2) -- Dark gray when not pushed
            end
            love.graphics.circle("fill", control.x, control.y, kButtonRadius)

            -- Draw button rim
            if control.pushed then
                love.graphics.setColor(0.6, 0.6, 0.6) -- 20% brighter when pushed
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
            end
            love.graphics.circle("line", control.x, control.y, kButtonRadius)
        end
    end

    -- Reset color and line width
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Helper function to find control under point
local function findControlAtPoint(x, y)
    for i, control in ipairs(controls) do
        local radius = control.type == kPot and kPotRadius or control.type ==
                           kEncoder and kEncoderRadius or kButtonRadius
        local dx = x - control.x
        local dy = y - control.y
        if dx * dx + dy * dy <= radius * radius then return i, control end
    end
    return nil
end

-- Mouse pressed handler
function controls.mousepressed(x, y, button)
    if not isActive then return false end
    local index, control = findControlAtPoint(x, y)
    if control then
        control.pushed = true
        -- Store initial position for dragging
        control.lastX = x
        control.lastY = y
        print(string.format("[Controls] Pressed %s (type: %s)", control.name,
                            control.type == kPot and "pot" or control.type ==
                                kEncoder and "encoder" or control.type ==
                                kButton and "button"))
        if control.type == kButton then
            -- Trigger button press callback if defined
            if controls.onButtonPress then
                controls.onButtonPress(index - 5) -- Convert to 1-4 button index
            end
        elseif control.type == kPot then
            -- Trigger pot press callback if defined
            if controls.onPotPress then
                controls.onPotPress(index) -- Pass the pot index (1-3)
            end
        elseif control.type == kEncoder then
            -- Trigger encoder press callback if defined
            if controls.onEncoderPress then
                controls.onEncoderPress(index - 3) -- Convert to 1-2 encoder index
            end
        end
        return true
    end
    return false
end

-- Mouse released handler
function controls.mousereleased(x, y, button)
    if not isActive then return false end
    local index, control = findControlAtPoint(x, y)
    if control then
        control.pushed = false
        -- Clear drag state
        control.lastX = nil
        control.lastY = nil
        print(string.format("[Controls] Released %s (value: %s)", control.name,
                            control.type == kPot and
                                string.format("%.2f", control.value) or
                                control.type == kEncoder and
                                tostring(control.value) or control.type ==
                                kButton and tostring(control.pushed)))
        if control.type == kButton then
            -- Trigger button release callback if defined
            if controls.onButtonRelease then
                controls.onButtonRelease(index - 5) -- Convert to 1-4 button index
            end
        elseif control.type == kPot then
            -- Trigger pot release callback if defined
            if controls.onPotRelease then
                controls.onPotRelease(index) -- Pass the pot index (1-3)
            end
        elseif control.type == kEncoder then
            -- Trigger encoder release callback if defined
            if controls.onEncoderRelease then
                controls.onEncoderRelease(index - 3) -- Convert to 1-2 encoder index
            end
        end
        return true
    end
    return false
end

-- Mouse moved handler
function controls.mousemoved(x, y, dx, dy)
    if not isActive then return false end
    local index, control = findControlAtPoint(x, y)
    if control and love.mouse.isDown(1) and control.lastX and control.lastY then
        if control.type == kPot then
            -- Update pot value based on vertical movement only
            -- Negative dy moves up (increases value)
            local oldValue = control.value
            control.value = math.max(0, math.min(1, control.value - dy * 0.005))
            if oldValue ~= control.value then
                print(string.format("[Controls] %s value changed: %.2f -> %.2f",
                                    control.name, oldValue, control.value))
            end
            if controls.onPotChange then
                controls.onPotChange(index, control.value)
            end
            -- Update last position
            control.lastY = y
            return true
        elseif control.type == kEncoder then
            -- Calculate movement relative to last position for smoother rotation
            local dx = x - control.lastX
            local delta = dx > 0 and 1 or dx < 0 and -1 or 0
            if delta ~= 0 then
                local oldValue = control.value
                control.value = control.value + delta
                print(string.format(
                          "[Controls] %s value changed: %d -> %d (delta: %d)",
                          control.name, oldValue, control.value, delta))
                if controls.onEncoderChange then
                    controls.onEncoderChange(index - 3, delta) -- Convert to 1-2 encoder index
                end
            end
            -- Update last position
            control.lastX = x
            return true
        end
    end
    return false
end

-- Get the height of the controls section
function controls.getHeight()
    return kPotRadius * 6 -- Approximate height of the entire control section
end

-- Callback setters
function controls.setCallbacks(callbacks)
    controls.onButtonPress = callbacks.onButtonPress
    controls.onButtonRelease = callbacks.onButtonRelease
    controls.onPotChange = callbacks.onPotChange
    controls.onPotPress = callbacks.onPotPress
    controls.onPotRelease = callbacks.onPotRelease
    controls.onEncoderChange = callbacks.onEncoderChange
    controls.onEncoderPress = callbacks.onEncoderPress
    controls.onEncoderRelease = callbacks.onEncoderRelease
end

-- Mouse wheel handler
function controls.wheelmoved(x, y)
    if not isActive then return false end
    local index, control = findControlAtPoint(love.mouse.getX(),
                                              love.mouse.getY())
    if control then
        if control.type == kPot then
            -- Update pot value based on vertical wheel movement
            -- Positive y is scroll up (increase value)
            local oldValue = control.value
            control.value = math.max(0, math.min(1, control.value + y * 0.05))
            if oldValue ~= control.value then
                print(string.format("[Controls] %s value changed: %.2f -> %.2f",
                                    control.name, oldValue, control.value))
                if controls.onPotChange then
                    controls.onPotChange(index, control.value)
                end
            end
            return true
        elseif control.type == kEncoder then
            -- Update encoder value based on vertical wheel movement
            -- Positive y is scroll up (increase value)
            local delta = y > 0 and 1 or y < 0 and -1 or 0
            if delta ~= 0 then
                local oldValue = control.value
                control.value = control.value + delta
                print(string.format(
                          "[Controls] %s value changed: %d -> %d (delta: %d)",
                          control.name, oldValue, control.value, delta))
                if controls.onEncoderChange then
                    controls.onEncoderChange(index - 3, delta) -- Convert to 1-2 encoder index
                end
            end
            return true
        end
    end
    return false
end

-- Set active state
function controls.setActive(active)
    isActive = active
    -- Reset all controls when deactivated
    if not active then
        for _, control in ipairs(controls) do
            control.pushed = false
            control.lastX = nil
            control.lastY = nil
        end
    end
end

-- Get current pot values
function controls.getPotValues()
    local potValues = {}
    for i = 1, 3 do potValues[i] = controls[i].value end
    return potValues
end

-- Simulation API for keyboard-triggered controls with visual feedback
function controls.simulateButtonPress(buttonIndex)
    if not isActive then return end
    local controlIndex = buttonIndex + 5 -- Buttons are at indices 6-9
    if controls[controlIndex] and controls[controlIndex].type == kButton then
        controls[controlIndex].pushed = true
        if controls.onButtonPress then
            controls.onButtonPress(buttonIndex)
        end
    end
end

function controls.simulateButtonRelease(buttonIndex)
    if not isActive then return end
    local controlIndex = buttonIndex + 5 -- Buttons are at indices 6-9
    if controls[controlIndex] and controls[controlIndex].type == kButton then
        controls[controlIndex].pushed = false
        if controls.onButtonRelease then
            controls.onButtonRelease(buttonIndex)
        end
    end
end

function controls.simulatePotPress(potIndex)
    if not isActive then return end
    if controls[potIndex] and controls[potIndex].type == kPot then
        controls[potIndex].pushed = true
        if controls.onPotPress then
            controls.onPotPress(potIndex)
        end
    end
end

function controls.simulatePotRelease(potIndex)
    if not isActive then return end
    if controls[potIndex] and controls[potIndex].type == kPot then
        controls[potIndex].pushed = false
        if controls.onPotRelease then
            controls.onPotRelease(potIndex)
        end
    end
end

function controls.simulateEncoderPress(encoderIndex)
    if not isActive then return end
    local controlIndex = encoderIndex + 3 -- Encoders are at indices 4-5
    if controls[controlIndex] and controls[controlIndex].type == kEncoder then
        controls[controlIndex].pushed = true
        if controls.onEncoderPress then
            controls.onEncoderPress(encoderIndex)
        end
    end
end

function controls.simulateEncoderRelease(encoderIndex)
    if not isActive then return end
    local controlIndex = encoderIndex + 3 -- Encoders are at indices 4-5
    if controls[controlIndex] and controls[controlIndex].type == kEncoder then
        controls[controlIndex].pushed = false
        if controls.onEncoderRelease then
            controls.onEncoderRelease(encoderIndex)
        end
    end
end

return controls
