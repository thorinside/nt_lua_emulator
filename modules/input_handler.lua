-- input_handler.lua
-- Module for handling mouse and input events in the emulator
local M = {} -- Module table

-- Local state variables
local dragging = false
local dragType = nil
local dragIndex = nil
local dragX, dragY = 0, 0
local isDraggingInsideCircle = false

-- BPM button holding state
local bpmButtonHeld = nil -- "minus" or "plus" when a button is held
local bpmHoldStartTime = 0
local bpmRepeatDelay = 0.3 -- Initial delay before repeating (seconds)
local bpmRepeatInterval = 0.08 -- How quickly to repeat adjustments (seconds)
local bpmNextRepeatTime = 0

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
    M.signalProcessor = deps.signalProcessor

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

    -- Set default UI scale factor
    M.uiScaleFactor = 1.0

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
    -- Handle BPM button holding
    if bpmButtonHeld and currentTime > bpmHoldStartTime + bpmRepeatDelay and
        currentTime >= bpmNextRepeatTime then
        -- Time to repeat the BPM adjustment
        local currentBPM = M.clockBPM
        local newBPM = currentBPM

        if bpmButtonHeld == "minus" then
            newBPM = math.max(M.minBPM, currentBPM - 1)
        elseif bpmButtonHeld == "plus" then
            newBPM = math.min(M.maxBPM, currentBPM + 1)
        end

        -- Only update if BPM changed
        if newBPM ~= currentBPM then
            -- Call the signal processor to update BPM
            if M.signalProcessor and M.signalProcessor.setClockBPM then
                M.signalProcessor.setClockBPM(newBPM)
            end
            -- Save state when BPM changes
            if M.saveIOState then M.saveIOState(true) end
        end

        -- Schedule next repeat
        bpmNextRepeatTime = currentTime + bpmRepeatInterval
    end

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
                elseif M.inputClock[inputIdx] then
                    -- From clock -> unipolar mode
                    M.inputClock[inputIdx] = false
                    M.inputPolarity[inputIdx] = kUnipolar
                    M.markMappingsChanged() -- Mark as changed when mode changes
                else
                    -- From unipolar -> bipolar (default)
                    M.inputPolarity[inputIdx] = kBipolar
                    M.inputClock[inputIdx] = false
                    M.markMappingsChanged() -- Mark as changed when mode changes
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
    -- Calculate scaled coordinates for other UI elements
    local lx = x / M.uiScaleFactor
    local ly = y / M.uiScaleFactor

    -- First check if controls handled the event
    if M.controls.mousepressed(lx, ly, button) then return true end

    local currentTime = love.timer.getTime()
    local isDoubleClick = false

    -- Check for double click
    if button == 1 and lastClickTime and (currentTime - lastClickTime) <
        doubleClickThreshold then isDoubleClick = true end

    -- Check if BPM adjustment buttons were clicked
    if button == 1 then
        local bpmButtons = M.io_panel.getBPMButtonPositions()
        if bpmButtons and bpmButtons.minus then
            -- Check minus button
            local btn = bpmButtons.minus
            if lx >= btn.x and lx <= btn.x + btn.width and ly >= btn.y and ly <=
                btn.y + btn.height then
                -- Decrease BPM by 1
                local currentBPM = M.clockBPM
                local newBPM = math.max(M.minBPM, currentBPM - 1)
                -- Call the signal processor to update BPM
                if M.signalProcessor and M.signalProcessor.setClockBPM then
                    M.signalProcessor.setClockBPM(newBPM)
                end
                -- Save state when BPM changes
                if M.saveIOState then M.saveIOState(true) end

                -- Set button held state for continuous adjustment
                bpmButtonHeld = "minus"
                bpmHoldStartTime = currentTime
                bpmNextRepeatTime = currentTime + bpmRepeatDelay

                return true
            end
        end

        if bpmButtons and bpmButtons.plus then
            -- Check plus button
            local btn = bpmButtons.plus
            if lx >= btn.x and lx <= btn.x + btn.width and ly >= btn.y and ly <=
                btn.y + btn.height then
                -- Increase BPM by 1
                local currentBPM = M.clockBPM
                local newBPM = math.min(M.maxBPM, currentBPM + 1)
                -- Call the signal processor to update BPM
                if M.signalProcessor and M.signalProcessor.setClockBPM then
                    M.signalProcessor.setClockBPM(newBPM)
                end
                -- Save state when BPM changes
                if M.saveIOState then M.saveIOState(true) end

                -- Set button held state for continuous adjustment
                bpmButtonHeld = "plus"
                bpmHoldStartTime = currentTime
                bpmNextRepeatTime = currentTime + bpmRepeatDelay

                return true
            end
        end
    end

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
            knobSpacing = M.paramKnobSpacing,
            uiScaleFactor = M.uiScaleFactor -- Add UI scale factor
        }

        -- Check if mouse is over any knob
        for i, sp in ipairs(M.scriptParameters) do
            -- Get knob position in screen coordinates
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            -- Calculate distance using raw mouse coordinates
            local dx = x - knobX
            local dy = y - knobY

            -- Use scaled radius for hit testing
            local hitRadius = M.paramKnobRadius * M.uiScaleFactor
            if dx * dx + dy * dy <= hitRadius * hitRadius then
                if isDoubleClick and lastClickType == "knob" and lastClickIndex ==
                    i then
                    -- Double-clicked on parameter knob - reset to default value
                    if sp.default then
                        -- Clear any automation
                        if M.parameterAutomation[i] then
                            M.parameterAutomation[i] = nil
                            sp.baseValue = nil
                        end

                        -- Reset to default value
                        sp.current = sp.default
                        -- Update the script's parameters using the helper module
                        M.helpers.updateScriptParameters(M.scriptParameters,
                                                         M.script)
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
    -- Calculate scaled coordinates
    local lx = x / M.uiScaleFactor
    local ly = y / M.uiScaleFactor

    -- Scale dx and dy as well
    local ldx = dx / M.uiScaleFactor
    local ldy = dy / M.uiScaleFactor

    -- Check if mouse moved away from held BPM button
    if bpmButtonHeld then
        local bpmButtons = M.io_panel.getBPMButtonPositions()
        if bpmButtons and bpmButtons[bpmButtonHeld] then
            local btn = bpmButtons[bpmButtonHeld]
            -- If mouse moved outside button bounds, clear held state
            if lx < btn.x or lx > btn.x + btn.width or ly < btn.y or ly > btn.y +
                btn.height then bpmButtonHeld = nil end
        end
    end

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
            -- Get knob position in screen coordinates
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            -- Calculate distance using raw mouse coordinates
            local dx = x - knobX
            local dy = y - knobY

            -- Use scaled radius for hit testing
            local hitRadius = M.paramKnobRadius * M.uiScaleFactor
            if dx * dx + dy * dy <= hitRadius * hitRadius then
                M.activeKnob = i
                break
            end
        end
    end

    return false
end

-- Mouse released event handler
function M.mousereleased(x, y, button)
    -- Calculate scaled coordinates for other UI elements
    local lx = x / M.uiScaleFactor
    local ly = y / M.uiScaleFactor

    -- First check if controls handled the event
    if M.controls.mousereleased(lx, ly, button) then return true end

    -- Clear BPM button held state
    if button == 1 and bpmButtonHeld then bpmButtonHeld = nil end

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
                    -- Get knob position in screen coordinates
                    local knobX, knobY =
                        M.parameter_knobs.getKnobPosition(i, params)
                    -- Calculate distance using raw mouse coordinates
                    local dx = x - knobX
                    local dy = y - knobY

                    -- Use scaled radius for hit testing
                    local hitRadius = M.paramKnobRadius * M.uiScaleFactor
                    if dx * dx + dy * dy <= hitRadius * hitRadius then
                        -- Store the current value as the base value before automation
                        sp.baseValue = sp.current
                        -- Link the physical input to this parameter
                        M.parameterAutomation[i] = dragIndex
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
    -- Get raw mouse coordinates 
    local mouseX = love.mouse.getX()
    local mouseY = love.mouse.getY()

    -- Calculate scaled coordinates for other UI elements
    local lx = mouseX / M.uiScaleFactor
    local ly = mouseY / M.uiScaleFactor

    -- First check if controls handled the event
    if M.controls.wheelmoved(x, y) then return true end

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
            -- Get knob position in screen coordinates
            local knobX, knobY = M.parameter_knobs.getKnobPosition(i, params)
            -- Calculate distance using raw mouse coordinates
            local dx = mouseX - knobX
            local dy = mouseY - knobY

            -- Use slightly larger hit radius for wheel events to make it more forgiving
            local hitRadius = M.paramKnobRadius * M.uiScaleFactor * 1.5
            if dx * dx + dy * dy <= hitRadius * hitRadius then
                local step = 1

                -- Adjust step size based on parameter type
                if sp.type == "float" then
                    if sp.scale == kBy10 then
                        -- For kBy10, use step of 1.0 in display units
                        step = 1.0
                    elseif sp.scale == kBy100 then
                        -- For kBy100, use step of 1.0 in display units
                        step = 1.0
                    elseif sp.scale == kBy1000 then
                        -- For kBy1000, use step of 1.0 in display units
                        step = 1.0
                    else
                        step = 0.1 -- Default for float without scaling
                    end
                else
                    step = 0.1 -- Default for integer and enum
                end

                -- y is positive for scroll up (increase) and negative for scroll down (decrease)
                local newValue = sp.current + (y * step)

                -- Clamp the value within range based on parameter type
                if sp.type == "enum" then
                    -- For enum parameters, clamp between 1 and the number of values
                    if sp.values then
                        newValue = math.max(1, math.min(#sp.values, newValue))
                    end
                else
                    -- For numeric parameters (integer, float), use min/max
                    newValue = math.max(sp.min, math.min(sp.max, newValue))
                end

                -- Only update if value actually changed
                if newValue ~= sp.current then
                    -- For automated parameters, adjust the base value to maintain the same CV offset
                    if M.parameterAutomation[i] then
                        local cvOffset = sp.current -
                                             (sp.baseValue or sp.current)
                        sp.baseValue = newValue - cvOffset
                    end
                    sp.current = newValue

                    -- Update the script's parameters using the helper module
                    M.helpers.updateScriptParameters(M.scriptParameters,
                                                     M.script)
                end

                return true
            end
        end
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

-- Function to cycle through input modes
function M.cycleInputMode(inputIdx)
    if not M.inputClock then return end

    -- If currently not a clock input, make it a clock input
    if not M.inputClock[inputIdx] then
        M.inputClock[inputIdx] = true
        M.inputPolarity[inputIdx] = kBipolar -- Reset polarity when making clock
        M.inputScaling[inputIdx] = 1.0 -- Reset scaling when making clock
        M.markMappingsChanged()
        return
    end

    -- If currently a clock input, make it a unipolar CV input
    if M.inputClock[inputIdx] and M.inputPolarity[inputIdx] == kBipolar then
        M.inputClock[inputIdx] = false
        M.inputPolarity[inputIdx] = kUnipolar
        M.markMappingsChanged()
        return
    end

    -- If currently a unipolar CV input, make it a bipolar CV input
    if not M.inputClock[inputIdx] and M.inputPolarity[inputIdx] == kUnipolar then
        M.inputPolarity[inputIdx] = kBipolar
        M.markMappingsChanged()
        return
    end
end

return M
