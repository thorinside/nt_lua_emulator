-- input_handler.lua
-- Module for handling mouse and input events in the emulator
local M = {} -- Module table

-- Local state variables
local dragging = false
local dragType = nil
local dragIndex = nil
local dragX, dragY = 0, 0
local isDraggingInsideCircle = false

local pendingPress = false
local pendingType = nil
local pendingIndex = nil
local pressX, pressY = 0, 0
local clickThreshold = 6

-- Double-click detection
local lastClickTime = 0
local lastClickType = nil
local lastClickIndex = nil
local doubleClickThreshold = 0.3 -- seconds

-- Parameter knob manipulation
local knobDragIndex = nil
local knobDragStartY = 0
local knobDragStartVal = 0
local knobDragSensitivity = 0.05

-- Input scaling
local scalingInput = nil
local scaleDragStartY = 0
local scaleDragSensitivity = 0.1

-- Active elements
local activeKnob = nil -- Currently hovered knob for mouse wheel control

-- Pending click actions
local pendingClickActions = {}

-- Initialize the module with required dependencies
function M.init(deps)
    -- Store dependencies
    M.display = deps.display
    M.io_panel = deps.io_panel
    M.controls = deps.controls
    M.parameter_knobs = deps.parameter_knobs
    M.helpers = deps.helpers
    M.notifications = deps.notifications
    M.markMappingsChanged = deps.markMappingsChanged
    M.saveIOState = deps.saveIOState

    -- Reset state
    dragging = false
    dragType = nil
    dragIndex = nil
    pendingPress = false
    pendingType = nil
    pendingIndex = nil
    lastClickTime = 0
    lastClickType = nil
    lastClickIndex = nil
    knobDragIndex = nil
    scalingInput = nil
    activeKnob = nil
    M.activeKnob = nil
    pendingClickActions = {}

    return M
end

-- Function to set state from emulator
function M.setState(state)
    M.script = state.script
    M.scriptInputCount = state.scriptInputCount
    M.scriptOutputCount = state.scriptOutputCount
    M.scriptInputAssignments = state.scriptInputAssignments
    M.scriptOutputAssignments = state.scriptOutputAssignments
    M.currentInputs = state.currentInputs
    M.currentOutputs = state.currentOutputs
    M.inputClock = state.inputClock
    M.inputPolarity = state.inputPolarity
    M.inputScaling = state.inputScaling
    M.clockBPM = state.clockBPM
    M.minBPM = state.minBPM
    M.maxBPM = state.maxBPM
    M.scriptParameters = state.scriptParameters
    M.parameterAutomation = state.parameterAutomation
    M.triggerPulseActive = state.triggerPulseActive
    M.triggerPulseTimes = state.triggerPulseTimes
    M.time = state.time
    M.lastPhysicalIOBottomY = state.lastPhysicalIOBottomY
    M.paramKnobRadius = state.paramKnobRadius
    M.paramKnobSpacing = state.paramKnobSpacing
    M.uiScaleFactor = state.uiScaleFactor
    M.scaledDisplayHeight = state.scaledDisplayHeight
    M.safeScriptCall = state.safeScriptCall
end

-- Update pending click actions (called during emulator's update loop)
function M.updatePendingClicks(currentTime)
    local i = 1
    while i <= #pendingClickActions do
        local action = pendingClickActions[i]

        if currentTime >= action.executeAfter then
            -- Time to execute this action
            if action.type == "cycleInputMode" then
                local inputIdx = action.inputIndex

                -- Execute the mode cycling logic
                if M.inputPolarity[inputIdx] == kBipolar and
                    not M.inputClock[inputIdx] then
                    -- From bipolar -> clock mode
                    M.inputClock[inputIdx] = true
                    M.markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to clock mode (delayed action)")
                elseif M.inputClock[inputIdx] then
                    -- From clock -> unipolar mode
                    M.inputClock[inputIdx] = false
                    M.inputPolarity[inputIdx] = kUnipolar
                    M.markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to unipolar mode (0V to +10V) (delayed action)")
                else
                    -- From unipolar -> bipolar (default)
                    M.inputPolarity[inputIdx] = kBipolar
                    M.inputClock[inputIdx] = false
                    M.markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to bipolar mode (-5V to +5V) (delayed action)")
                end
            end

            -- Remove this action
            table.remove(pendingClickActions, i)
        else
            -- Skip to next action
            i = i + 1
        end
    end
end

-- Mouse pressed event handler
function M.mousepressed(x, y, button)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = M.scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / M.uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / M.uiScaleFactor +
                 (displayAreaHeight / M.uiScaleFactor)
    else
        ly = y / M.uiScaleFactor
    end

    -- First check if controls handled the event
    if M.controls.mousepressed(lx, ly, button) then return true end

    local currentTime = love.timer.getTime()
    local isDoubleClick = false

    -- Check for double click
    if button == 1 and lastClickTime and (currentTime - lastClickTime) <
        doubleClickThreshold then isDoubleClick = true end

    -- Check for right-click on physical inputs (for scaling)
    if button == 2 then
        -- Right-click on physical inputs
        local inputPos = M.io_panel.getPhysicalInputPositions()
        if inputPos then
            for i, pos in ipairs(inputPos) do
                local dx = lx - pos[1]
                local dy = ly - pos[2]
                if math.sqrt(dx * dx + dy * dy) <= 15 then
                    -- Allow scaling for both normal and clock inputs
                    scalingInput = i
                    scaleDragStartY = ly
                    return true
                end
            end
        end
    end

    -- Check parameter knobs
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 24, -- Use the stored Y position
            knobRadius = M.paramKnobRadius,
            knobSpacing = M.paramKnobSpacing
        }
        for i, sp in ipairs(M.scriptParameters) do
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            local dx = lx - knobX
            local dy = ly - knobY
            if dx * dx + dy * dy <= M.paramKnobRadius ^ 2 then
                if isDoubleClick and lastClickType == "knob" and lastClickIndex ==
                    i then
                    -- Double-clicked on parameter knob - reset to default value
                    if sp.default then
                        -- Clear any automation
                        if M.parameterAutomation[i] then
                            print("Removed automation for parameter " .. i ..
                                      " (" .. sp.name .. ")")
                            M.parameterAutomation[i] = nil
                            sp.baseValue = nil
                        end

                        -- Reset to default value
                        sp.current = sp.default
                        -- Update the script's parameters using the helper module
                        M.helpers.updateScriptParameters(M.scriptParameters,
                                                         M.script)
                        print("Reset parameter " .. i .. " (" .. sp.name ..
                                  ") to default value: " .. sp.default)
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return true
                end

                -- Start knob drag for normal click
                if button == 1 then
                    knobDragIndex = i
                    knobDragStartY = ly
                    knobDragStartVal = sp.current
                    dragX = lx -- Initialize horizontal drag position
                    dragY = ly -- Initialize vertical drag position

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "knob"
                    lastClickIndex = i
                    return true
                end
            end
        end
    end

    -- Script inputs
    local scriptInputPos = M.io_panel.getScriptInputPositions()
    if scriptInputPos then
        for i, pos in ipairs(scriptInputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 12 then
                if isDoubleClick and lastClickType == "scriptInput" and
                    lastClickIndex == i then
                    -- Double-clicked on script input - clear assignment
                    if M.scriptInputAssignments[i] then
                        print("Cleared input assignment for script input " .. i)
                        M.scriptInputAssignments[i] = nil
                        M.markMappingsChanged()
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return true
                end

                -- Store click for double-click detection
                lastClickTime = currentTime
                lastClickType = "scriptInput"
                lastClickIndex = i
                return true
            end
        end
    end

    -- Script outputs
    local scriptOutputPos = M.io_panel.getScriptOutputPositions()
    if scriptOutputPos then
        for i, pos in ipairs(scriptOutputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 12 then
                if isDoubleClick and lastClickType == "scriptOutput" and
                    lastClickIndex == i then
                    -- Double-clicked on script output - clear assignment
                    if M.scriptOutputAssignments[i] then
                        -- Clear voltage on the physical output that was connected
                        M.currentOutputs[M.scriptOutputAssignments[i]] = 0
                        print("Cleared output assignment for script output " ..
                                  i)
                        M.scriptOutputAssignments[i] = nil
                        M.markMappingsChanged()
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return true
                end

                -- Store click for double-click detection
                lastClickTime = currentTime
                lastClickType = "scriptOutput"
                lastClickIndex = i
                return true
            end
        end
    end

    -- Physical inputs
    local inputPos = M.io_panel.getPhysicalInputPositions()
    if inputPos then
        for i, pos in ipairs(inputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                if button == 2 then
                    -- Right button is only for dragging to set attenuation level
                    pendingPress = true
                    pendingType = "input"
                    pendingIndex = i
                    pressX, pressY = lx, ly
                    return true
                elseif button == 1 then
                    if isDoubleClick and lastClickType == "physicalInput" and
                        lastClickIndex == i then
                        -- Double click to reset to default state
                        local changed = (M.inputClock[i] ~= false) or
                                            (M.inputPolarity[i] ~= kBipolar) or
                                            (M.inputScaling[i] ~= 1.0)

                        M.inputClock[i] = false
                        M.inputPolarity[i] = kBipolar
                        M.inputScaling[i] = 1.0

                        if changed then
                            M.markMappingsChanged() -- Mark as changed when reset
                        end

                        print("Reset input " .. i ..
                                  " to default state (bipolar, no attenuation)")

                        -- Remove any pending actions for this input
                        for j = #pendingClickActions, 1, -1 do
                            if pendingClickActions[j].type == "cycleInputMode" and
                                pendingClickActions[j].inputIndex == i then
                                table.remove(pendingClickActions, j)
                            end
                        end

                        -- Reset double-click state
                        lastClickTime = 0
                        return true
                    end

                    pendingPress = true
                    pendingType = "input"
                    pendingIndex = i
                    pressX, pressY = lx, ly

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "physicalInput"
                    lastClickIndex = i
                    return true
                end
            end
        end
    end

    -- Physical outputs
    local outputPos = M.io_panel.getPhysicalOutputPositions()
    if outputPos then
        for i, pos in ipairs(outputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                if button == 1 then
                    pendingPress = true
                    pendingType = "output"
                    pendingIndex = i
                    pressX, pressY = lx, ly

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "physicalOutput"
                    lastClickIndex = i
                    return true
                end
            end
        end
    end

    -- Reset double-click detection if clicking elsewhere
    lastClickTime = 0
    lastClickType = nil
    lastClickIndex = nil

    return false
end

-- Mouse moved event handler
function M.mousemoved(x, y, dx, dy)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = M.scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / M.uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / M.uiScaleFactor +
                 (displayAreaHeight / M.uiScaleFactor)
    else
        ly = y / M.uiScaleFactor
    end

    -- Debug output
    print(string.format(
              "Mouse moved: raw (%.1f, %.1f), scaled (%.1f, %.1f), scale factor: %.1f",
              x, y, lx, ly, M.uiScaleFactor))

    -- First check if controls handled the event
    if M.controls.mousemoved(lx, ly, dx, dy) then return true end

    -- Handle scaling inputs with vertical drag
    if scalingInput then
        local deltaY = scaleDragStartY - ly

        if M.inputClock[scalingInput] then
            -- For clock inputs, modify the BPM instead of scaling
            -- Use a less sensitive adjustment for BPM
            local bpmDelta = deltaY * 1.0 -- Reduced from 2.0 to 1.0
            local newBPM = M.clockBPM + bpmDelta
            newBPM = math.max(M.minBPM, math.min(M.maxBPM, newBPM))

            if newBPM ~= M.clockBPM then
                M.clockBPM = newBPM
                M.markMappingsChanged() -- Mark as changed when BPM changes
                print(string.format("Clock BPM adjusted to: %.1f", M.clockBPM))
            end
        else
            -- For normal inputs, adjust scaling as before
            local newScale = M.inputScaling[scalingInput] +
                                 (deltaY * scaleDragSensitivity)
            newScale = math.max(0.0, math.min(1.0, newScale))

            if newScale ~= M.inputScaling[scalingInput] then
                M.inputScaling[scalingInput] = newScale
                M.markMappingsChanged() -- Mark as changed when scaling changes
            end
        end

        scaleDragStartY = ly
        return true
    end

    -- Handle pending press that could become a drag
    if pendingPress and not dragging then
        local dist = math.sqrt((lx - pressX) ^ 2 + (ly - pressY) ^ 2)
        if dist > clickThreshold then
            dragging = true
            dragType = pendingType
            dragIndex = pendingIndex
            dragX = lx
            dragY = ly
            pendingPress = false
        end
    end

    -- Update drag line position
    if dragging then
        dragX = lx
        dragY = ly
    end

    -- Handle parameter knob dragging
    if knobDragIndex then
        local sp = M.scriptParameters[knobDragIndex]
        if sp then
            -- Handle dragging differently based on automation
            local isAutomated = M.parameterAutomation[knobDragIndex] ~= nil

            if sp.type == "integer" then
                -- Integer parameters always use whole number steps
                local stepSize = dy > 0 and -1 or 1

                if isAutomated then
                    local newBaseVal = (sp.baseValue or sp.current) + stepSize
                    newBaseVal = math.floor(
                                     math.max(sp.min,
                                              math.min(sp.max, newBaseVal)) +
                                         0.5)
                    sp.baseValue = newBaseVal
                else
                    local newVal = sp.current + stepSize
                    newVal = math.floor(math.max(sp.min,
                                                 math.min(sp.max, newVal)) + 0.5)
                    sp.current = newVal
                end

            elseif sp.type == "float" then
                -- Float parameters use scaled values
                local range = sp.max - sp.min
                local stepSize = -dy * (range / 200) -- Adjust sensitivity based on parameter range

                if isAutomated then
                    local newBaseVal = (sp.baseValue or sp.current) + stepSize
                    newBaseVal = math.max(sp.min, math.min(sp.max, newBaseVal))
                    sp.baseValue = newBaseVal
                else
                    local newVal = sp.current + stepSize
                    newVal = math.max(sp.min, math.min(sp.max, newVal))
                    sp.current = newVal
                end

            else -- enum type
                -- Enum parameters always use whole number indices
                local intDelta = dy > 0 and -1 or 1 -- Flip direction for more intuitive control

                if isAutomated then
                    local newBaseIndex = (sp.baseValue or sp.current) + intDelta
                    newBaseIndex = math.max(1,
                                            math.min(#sp.values, newBaseIndex))
                    sp.baseValue = newBaseIndex
                else
                    local newIndex = sp.current + intDelta
                    newIndex = math.max(1, math.min(#sp.values, newIndex))
                    sp.current = newIndex
                end
            end

            -- Update the script's parameters immediately
            M.helpers.updateScriptParameters(M.scriptParameters, M.script)
        end
    end

    -- Update active knob for wheel control
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 24, -- Use the stored Y position
            knobRadius = M.paramKnobRadius,
            knobSpacing = M.paramKnobSpacing,
            uiScaleFactor = M.uiScaleFactor -- Add UI scale factor
        }

        -- Reset active knob
        local prevActiveKnob = M.activeKnob
        M.activeKnob = nil

        -- Check if mouse is over any knob
        for i, sp in ipairs(M.scriptParameters) do
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            local dx = lx - knobX
            local dy = ly - knobY
            if dx * dx + dy * dy <= M.paramKnobRadius * M.paramKnobRadius then
                M.activeKnob = i
                if prevActiveKnob ~= i then
                    print("Mouse hovering over knob " .. i .. " (" .. sp.name ..
                              ")")
                end
                break
            end
        end

        if prevActiveKnob and not M.activeKnob then
            print("Mouse no longer hovering over any knob")
        end
    end

    return false
end

-- Mouse released event handler
function M.mousereleased(x, y, button)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = M.scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / M.uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / M.uiScaleFactor +
                 (displayAreaHeight / M.uiScaleFactor)
    else
        ly = y / M.uiScaleFactor
    end

    -- First check if controls handled the event
    if M.controls.mousereleased(lx, ly, button) then return true end

    -- If we were scaling an input, stop now
    if scalingInput then
        scalingInput = nil
        return true
    end

    -- Handle pending press that didn't become a drag
    if pendingPress then
        if pendingType == "input" then
            -- Check if this input is connected to a kTrigger script input
            local isTriggerInput = false
            local scriptInputIdx = nil
            for idx, assignedPhysInput in pairs(M.scriptInputAssignments) do
                if assignedPhysInput == pendingIndex and type(M.script.inputs) ==
                    "table" and M.script.inputs[idx] == kTrigger then
                    isTriggerInput = true
                    scriptInputIdx = idx
                    break
                end
            end

            if isTriggerInput and scriptInputIdx then
                -- For trigger inputs, send a 10ms pulse
                M.triggerPulseActive[pendingIndex] = true
                M.triggerPulseTimes[pendingIndex] = M.time
                -- Call the script's trigger function if it exists
                if M.script.trigger then
                    -- Pass the script input index, not the physical input index
                    M.safeScriptCall(M.script.trigger, M.script, scriptInputIdx)
                end
            else
                -- For non-trigger inputs, cycle through modes as before
                local currentTime = love.timer.getTime()
                table.insert(pendingClickActions, {
                    type = "cycleInputMode",
                    inputIndex = pendingIndex,
                    executeAfter = currentTime + doubleClickThreshold
                })
            end
        end
        pendingPress = false
        return true
    end

    -- Handle dragging connections
    if dragging then
        if dragType == "input" then
            -- Check if we're over a parameter knob
            if M.scriptParameters then
                local params = {
                    scriptParameters = M.scriptParameters,
                    displayWidth = M.display.getConfig().width,
                    panelY = M.lastPhysicalIOBottomY + 24,
                    knobRadius = M.paramKnobRadius,
                    knobSpacing = M.paramKnobSpacing,
                    uiScaleFactor = M.uiScaleFactor -- Add UI scale factor
                }

                for i, sp in ipairs(M.scriptParameters) do
                    local knobX, knobY =
                        M.parameter_knobs.getKnobPosition(i, params)
                    local dx = lx - knobX
                    local dy = ly - knobY
                    if dx * dx + dy * dy <= M.paramKnobRadius *
                        M.paramKnobRadius then
                        -- Store the current value as the base value before automation
                        sp.baseValue = sp.current
                        -- Link the physical input to this parameter
                        M.parameterAutomation[i] = dragIndex
                        print(string.format(
                                  "Linked physical input %d to parameter %d (%s)",
                                  dragIndex, i, sp.name))
                        break
                    end
                end
            end

            -- Check if we're over a script input
            local scriptInputPos = M.io_panel.getScriptInputPositions()
            if scriptInputPos then
                for i, pos in ipairs(scriptInputPos) do
                    local dx = lx - pos[1]
                    local dy = ly - pos[2]
                    if math.sqrt(dx * dx + dy * dy) <= 12 then
                        M.scriptInputAssignments[i] = dragIndex
                        M.markMappingsChanged()
                        print("Connected physical input " .. dragIndex ..
                                  " to script input " .. i)
                        break
                    end
                end
            end
        elseif dragType == "output" then
            -- Check if we're over a script output
            local scriptOutputPos = M.io_panel.getScriptOutputPositions()
            if scriptOutputPos then
                for i, pos in ipairs(scriptOutputPos) do
                    local dx = lx - pos[1]
                    local dy = ly - pos[2]
                    if math.sqrt(dx * dx + dy * dy) <= 12 then
                        M.scriptOutputAssignments[i] = dragIndex
                        M.markMappingsChanged()
                        print("Connected script output " .. i ..
                                  " to physical output " .. dragIndex)
                        break
                    end
                end
            end
        end
        dragging = false
    end

    -- Reset knob dragging state
    if knobDragIndex then knobDragIndex = nil end

    return false
end

-- Mouse wheel event handler
function M.wheelmoved(x, y)
    print("Wheel moved: x=" .. x .. ", y=" .. y .. ", activeKnob=" ..
              tostring(M.activeKnob))

    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = M.scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = love.mouse.getX() / M.uiScaleFactor
    local ly = love.mouse.getY()
    if ly > displayAreaHeight then
        ly = (ly - displayAreaHeight) / M.uiScaleFactor +
                 (displayAreaHeight / M.uiScaleFactor)
    else
        ly = ly / M.uiScaleFactor
    end

    -- Debug output
    print(string.format(
              "  Mouse coordinates: raw (%.1f, %.1f), scaled (%.1f, %.1f), scale factor: %.1f",
              love.mouse.getX(), love.mouse.getY(), lx, ly, M.uiScaleFactor))

    -- First check if controls handled the event
    if M.controls.wheelmoved(x, y) then
        print("  Controls handled the wheel event")
        return true
    end

    -- Find the knob under the cursor directly in this function
    -- rather than relying on mousemoved to set it
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 24, -- Use the stored Y position
            knobRadius = M.paramKnobRadius,
            knobSpacing = M.paramKnobSpacing,
            uiScaleFactor = M.uiScaleFactor -- Add UI scale factor
        }

        -- Check if mouse is over any knob
        for i, sp in ipairs(M.scriptParameters) do
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            local dx = lx - knobX
            local dy = ly - knobY

            -- Use slightly larger hit radius for wheel events to make it more forgiving
            local hitRadiusSq = (M.paramKnobRadius * 1.5) *
                                    (M.paramKnobRadius * 1.5)

            if dx * dx + dy * dy <= hitRadiusSq then
                print("  Found knob under cursor: " .. i .. " (" .. sp.name ..
                          ")")

                local step = 1

                -- Adjust step size based on parameter type
                if sp.type == "float" then
                    if sp.scale == kBy10 then
                        -- For kBy10, use step of 1.0 in display units
                        step = 1.0
                        print("  Using kBy10 step: " .. step)
                    elseif sp.scale == kBy100 then
                        -- For kBy100, use step of 1.0 in display units
                        step = 1.0
                        print("  Using kBy100 step: " .. step)
                    elseif sp.scale == kBy1000 then
                        -- For kBy1000, use step of 1.0 in display units
                        step = 1.0
                        print("  Using kBy1000 step: " .. step)
                    else
                        step = 0.1 -- Default for float without scaling
                        print("  Using default float step: " .. step)
                    end
                else
                    print("  Using default step: " .. step)
                end

                -- y is positive for scroll up (increase) and negative for scroll down (decrease)
                local newValue = sp.current + (y * step)
                print("  New value (before clamping): " .. newValue)

                -- Clamp the value within range based on parameter type
                if sp.type == "enum" then
                    -- For enum parameters, clamp between 1 and the number of values
                    if sp.values then
                        newValue = math.max(1, math.min(#sp.values, newValue))
                        print("  Clamped enum value: " .. newValue .. " (" ..
                                  sp.values[math.floor(newValue)] .. ")")
                    end
                else
                    -- For numeric parameters (integer, float), use min/max
                    newValue = math.max(sp.min, math.min(sp.max, newValue))
                    print("  Clamped numeric value: " .. newValue)
                end

                -- Only update if value actually changed
                if newValue ~= sp.current then
                    -- For automated parameters, adjust the base value to maintain the same CV offset
                    if M.parameterAutomation[i] then
                        local cvOffset = sp.current -
                                             (sp.baseValue or sp.current)
                        sp.baseValue = newValue - cvOffset
                        print(
                            "  Updated base value for automated parameter: " ..
                                sp.baseValue)
                    end
                    sp.current = newValue
                    print("  Set new value: " .. sp.current)

                    -- Update the script's parameters using the helper module
                    M.helpers.updateScriptParameters(M.scriptParameters,
                                                     M.script)
                    print("  Updated script parameters")
                end

                return true
            end
        end

        print("  No knob found under cursor")
    else
        print("  No script parameters available")
    end

    return false
end

-- Get the dragging state for drawing
function M.getDraggingState()
    return {
        dragging = dragging,
        dragType = dragType,
        dragIndex = dragIndex,
        dragX = dragX,
        dragY = dragY
    }
end

-- Get the active knob index
function M.getActiveKnob() return M.activeKnob end

-- Reset dragging state
function M.resetDragging()
    dragging = false
    dragType = nil
    dragIndex = nil
end

return M
