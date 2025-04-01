-- input_handler.lua
-- Module for handling mouse and input events in the emulator
local M = {} -- Module table

-- Helper function for sign (Lua 5.1/5.2 compatibility)
local function sign(x) return x > 0 and 1 or (x < 0 and -1 or 0) end

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

-- Enum wheel accumulator
local enumWheelAccumulator = 0
local enumAccumulatorIndex = nil -- Which knob index the accumulator applies to

-- Active elements
local activeKnob = nil -- Currently hovered knob for mouse wheel control

-- Pending click actions
local pendingClickActions = {}
local parameterTargetValues = {} -- Table to store target values for smoothing

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
    parameterTargetValues = {} -- Reset target values on init

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

    -- Add parameter smoothing logic
    local smoothingAlpha = 0.2 -- Tunable smoothing factor (lower = smoother, slower)
    local smoothingThreshold = 0.005 -- Stop smoothing when difference is small (relative to range for floats?)
    local paramsChanged = false

    if M.scriptParameters and parameterTargetValues then
        for i, targetValue in pairs(parameterTargetValues) do
            local sp = M.scriptParameters[i]
            if sp then
                local currentValue = sp.current
                local diff = targetValue - currentValue
                -- Define a threshold to stop smoothing (e.g., 1% of a step or a small absolute value)
                local snapThreshold = 0.01 -- Threshold for floats

                if math.abs(diff) > snapThreshold then
                    local smoothedValue =
                        smoothingAlpha * targetValue + (1 - smoothingAlpha) *
                            currentValue

                    -- Apply type-specific rounding/clamping AFTER smoothing
                    -- Smoothing only applies to float types
                    smoothedValue = math.max(sp.min,
                                             math.min(sp.max, smoothedValue))

                    -- Update only if the smoothed value actually changes the effective value (especially for int/enum)
                    if smoothedValue ~= currentValue then
                        sp.current = smoothedValue
                        paramsChanged = true

                        -- If parameter is automated, also update baseValue
                        if M.parameterAutomation and M.parameterAutomation[i] then
                            sp.baseValue = smoothedValue
                        end
                    end
                else
                    -- Difference is small, snap to target and remove from smoothing list
                    local finalValue = targetValue -- Start with the exact target

                    -- Apply final rounding/clamping for integer/enum types
                    -- Snap float value
                    finalValue = math.max(sp.min, math.min(sp.max, finalValue))

                    -- Update only if the final snapped value is different
                    if finalValue ~= currentValue then
                        sp.current = finalValue
                        paramsChanged = true

                        if M.parameterAutomation and M.parameterAutomation[i] then
                            sp.baseValue = sp.current
                        end
                    end
                    parameterTargetValues[i] = nil -- Stop smoothing for this parameter
                end
            else
                parameterTargetValues[i] = nil -- Remove target if parameter doesn't exist anymore
            end
        end
    end

    -- Update script parameters if any changes were made during smoothing
    if paramsChanged then
        M.helpers.updateScriptParameters(M.scriptParameters, M.script)
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

    -- Check parameter knobs
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 60, -- Changed from 24 to 60 to match drawing position
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
                            sp.baseValue = nil -- Clear baseValue when removing automation
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
                    -- We still need to track the knob for double-click reset functionality
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

    -- Input scaling is now handled in wheelmoved function
    -- scalingInput state var is still kept for tracking active input

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
        -- Disable mouse dragging behavior for parameter knobs
        -- Just continue to track the knob for mouse release but don't adjust values
        -- Values will only be changed using mouse wheel now

        -- Update the script's parameters immediately
        M.helpers.updateScriptParameters(M.scriptParameters, M.script)
    end

    -- Update active knob for wheel control
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 60, -- Changed from 24 to 60 to match drawing position
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

    -- Note: Input scaling is now handled by mouse wheel

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
                    if M.signalProcessor and M.signalProcessor.scriptManager then
                        M.signalProcessor.scriptManager.callScriptTrigger({
                            input = scriptInputIdx
                        })
                    else
                        M.safeScriptCall(M.script.trigger, M.script,
                                         scriptInputIdx)
                    end
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
                    panelY = M.lastPhysicalIOBottomY + 60, -- Changed from 24 to 60 to match drawing position
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

    -- Check if mouse is over a physical input for scaling
    local inputPos = M.io_panel.getPhysicalInputPositions()
    if inputPos then
        for i, pos in ipairs(inputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                -- We're over a physical input, adjust its scaling with mouse wheel
                if M.inputClock[i] then
                    -- For clock inputs, modify the BPM
                    local bpmDelta = y > 0 and 1 or -1
                    if love.keyboard.isDown("lshift") or
                        love.keyboard.isDown("rshift") then
                        bpmDelta = bpmDelta * 0.1 -- Fine control with shift
                    end

                    local newBPM = M.clockBPM + bpmDelta
                    newBPM = math.max(M.minBPM, math.min(M.maxBPM, newBPM))

                    if newBPM ~= M.clockBPM then
                        M.clockBPM = newBPM
                        M.markMappingsChanged() -- Mark as changed when BPM changes
                    end
                else
                    -- For normal inputs, adjust scaling
                    local scaleDelta = y > 0 and 0.05 or -0.05
                    if love.keyboard.isDown("lshift") or
                        love.keyboard.isDown("rshift") then
                        scaleDelta = scaleDelta * 0.2 -- Fine control with shift
                    end

                    local newScale = M.inputScaling[i] + scaleDelta
                    newScale = math.max(0.0, math.min(1.0, newScale))

                    if newScale ~= M.inputScaling[i] then
                        M.inputScaling[i] = newScale
                        M.markMappingsChanged() -- Mark as changed when scaling changes
                    end
                end

                return true
            end
        end
    end

    -- Find the knob under the cursor directly in this function
    -- rather than relying on mousemoved to set it
    if M.scriptParameters then
        local params = {
            scriptParameters = M.scriptParameters,
            displayWidth = M.display.getConfig().width,
            panelY = M.lastPhysicalIOBottomY + 60, -- Changed from 24 to 60 to match drawing position
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
                local direction = y > 0 and 1 or (y < 0 and -1 or 0) -- Normalize wheel direction
                local fineControlMultiplier = 0.1 -- Use 10% step for fine control
                local newValue = sp.current -- Initialize with current value

                -- Adjust step size based on parameter type
                if sp.type == "float" then
                    local range = sp.max - sp.min
                    if range <= 0 then range = 1 end -- Avoid division by zero for fixed values

                    if sp.scale == kBy10 then
                        step = 10.0 -- Corresponds to 1.0 display unit change
                        if love.keyboard.isDown("lshift") or
                            love.keyboard.isDown("rshift") then
                            step = 1.0 -- Fine control: 0.1 display unit change
                        end
                        newValue = sp.current + direction * step
                    elseif sp.scale == kBy100 then
                        step = 100.0 -- Corresponds to 1.0 display unit change
                        if love.keyboard.isDown("lshift") or
                            love.keyboard.isDown("rshift") then
                            step = 10.0 -- Fine control: 0.1 display unit change
                        end
                        newValue = sp.current + direction * step
                    elseif sp.scale == kBy1000 then
                        step = 1000.0 -- Corresponds to 1.0 display unit change
                        if love.keyboard.isDown("lshift") or
                            love.keyboard.isDown("rshift") then
                            step = 100.0 -- Fine control: 0.1 display unit change
                        end
                        newValue = sp.current + direction * step
                    else
                        -- Default float: Step is a small percentage of the range
                        step = range * 0.01 -- 1% of range per wheel click
                        if step == 0 then step = 0.01 end -- Minimum step if range is very small or 0

                        if love.keyboard.isDown("lshift") or
                            love.keyboard.isDown("rshift") then
                            step = step * fineControlMultiplier -- Fine control
                        end
                        newValue = sp.current + direction * step
                    end
                    -- Clamp float value
                    newValue = math.max(sp.min, math.min(sp.max, newValue))

                elseif sp.type == "integer" then
                    step = 1 -- Step by 1 for integers
                    local largeStep = 5 -- Larger step for shift+scroll on integers

                    if love.keyboard.isDown("lshift") or
                        love.keyboard.isDown("rshift") then
                        -- Shift IS down: Use larger step if range is wide
                        if (sp.max - sp.min) > 10 then
                            step = largeStep
                        end
                        -- Note: step remains 1 if range is small
                    else
                        -- Shift IS NOT down: Use standard step (already 1)
                        -- No change needed, step defaults to 1
                    end

                    -- Calculate new value using the determined step
                    newValue = sp.current + direction * step

                    -- Clamp integer value first
                    newValue = math.max(sp.min, math.min(sp.max, newValue))
                    -- Then round to nearest integer
                    newValue = math.floor(newValue + 0.5)

                    -- Update Integer parameters directly (no smoothing for discrete steps)
                    if newValue ~= sp.current then
                        sp.current = newValue
                        -- If parameter is automated, also update baseValue
                        if M.parameterAutomation and M.parameterAutomation[i] then
                            sp.baseValue = newValue
                        end
                        -- Update the script's parameters using the helper module
                        M.helpers.updateScriptParameters(M.scriptParameters,
                                                         M.script)
                    end

                elseif sp.type == "enum" then
                    if sp.values then
                        local totalValues = #sp.values
                        local changedEnum = false -- Flag to track if enum value actually changes
                        if totalValues > 0 then
                            step = 1 -- Step by 1 index
                            -- Always step by 1 for enums, remove shift modifier sensitivity

                            -- Accumulator Logic
                            if enumAccumulatorIndex ~= i or
                                (direction ~= 0 and sign(direction) ~=
                                    sign(enumWheelAccumulator)) then
                                -- Reset accumulator if knob changes or direction reverses
                                enumWheelAccumulator = 0
                                enumAccumulatorIndex = i
                            end

                            if direction ~= 0 then
                                enumWheelAccumulator =
                                    enumWheelAccumulator + direction
                            end

                            -- Only trigger change if accumulator threshold is met
                            local triggerThreshold = 2
                            local actualDirection = 0
                            if math.abs(enumWheelAccumulator) >=
                                triggerThreshold then
                                actualDirection = sign(enumWheelAccumulator)
                                enumWheelAccumulator = 0 -- Reset after triggering
                            end

                            -- Apply change only if threshold was met
                            newValue = sp.current + actualDirection * step
                            -- Clamp enum index
                            newValue = math.max(1,
                                                math.min(totalValues, newValue))
                            -- Update Enum parameters directly (no smoothing for discrete steps)
                            if newValue ~= sp.current then
                                sp.current = newValue
                                changedEnum = true -- Mark that value changed
                                -- If parameter is automated, also update baseValue
                                if M.parameterAutomation and
                                    M.parameterAutomation[i] then
                                    sp.baseValue = newValue
                                end
                                -- Update the script's parameters using the helper module
                                M.helpers.updateScriptParameters(
                                    M.scriptParameters, M.script)
                            end
                        end
                    else
                        -- Fallback for enums without values array (treat as integer)
                        step = 1
                        if love.keyboard.isDown("lshift") or
                            love.keyboard.isDown("rshift") then
                            step = 5
                        end
                        newValue = sp.current + direction * step
                        newValue = math.max(sp.min or 1,
                                            math.min(sp.max or 1, newValue))
                        newValue = math.floor(newValue + 0.5)

                        -- Also update fallback enums directly
                        if newValue ~= sp.current then
                            sp.current = newValue
                            -- If parameter is automated, also update baseValue
                            if M.parameterAutomation and
                                M.parameterAutomation[i] then
                                sp.baseValue = newValue
                            end
                            -- Update the script's parameters using the helper module
                            M.helpers.updateScriptParameters(M.scriptParameters,
                                                             M.script)
                        end
                    end

                    -- Set target for float smoothing (only floats should reach here without returning)
                    if sp.type == "float" then
                        parameterTargetValues[i] = newValue
                    end

                end

                return true -- Indicate event was handled
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

-- Function to update parameter smoothing
function M.updateParameterSmoothing(dt) -- dt might be useful later for frame-rate independence
    local smoothingAlpha = 0.2 -- Tunable smoothing factor (lower = smoother, slower)
    local paramsChanged = false

    if M.scriptParameters and parameterTargetValues then
        for i, targetValue in pairs(parameterTargetValues) do
            local sp = M.scriptParameters[i]
            if sp then
                local currentValue = sp.current
                local diff = targetValue - currentValue
                -- Define a threshold to stop smoothing (e.g., 1% of a step or a small absolute value)
                local snapThreshold = 0.01 -- Threshold only relevant for floats now

                if math.abs(diff) > snapThreshold then
                    local smoothedValue =
                        smoothingAlpha * targetValue + (1 - smoothingAlpha) *
                            currentValue

                    -- Apply type-specific rounding/clamping AFTER smoothing
                    if sp.type == "float" then
                        smoothedValue = math.max(sp.min, math.min(sp.max,
                                                                  smoothedValue))
                    else
                        -- Should not happen if only floats use smoothing, but handle defensively
                        smoothedValue = currentValue -- Don't change non-floats here
                    end

                    -- Update only if the smoothed value actually changes the effective value (especially for int/enum)
                    if smoothedValue ~= currentValue then
                        sp.current = smoothedValue
                        paramsChanged = true

                        -- If parameter is automated, also update baseValue
                        if M.parameterAutomation and M.parameterAutomation[i] then
                            sp.baseValue = smoothedValue
                        end
                    end
                else
                    -- Difference is small, snap to target and remove from smoothing list
                    local finalValue = targetValue -- Start with the exact target

                    -- Apply final rounding/clamping for integer/enum types
                    if sp.type == "integer" then
                        finalValue = math.max(sp.min,
                                              math.min(sp.max, finalValue))
                        finalValue = math.floor(finalValue + 0.5)
                    elseif sp.type == "float" then -- Only floats need snapping logic here
                        finalValue = math.max(sp.min,
                                              math.min(sp.max, finalValue))
                    else
                        -- Enums/Others already snapped or handled directly
                        finalValue = currentValue -- Fallback, should already be correct
                    end

                    -- Update only if the final snapped value is different
                    if finalValue ~= currentValue then
                        sp.current = finalValue
                        paramsChanged = true

                        if M.parameterAutomation and M.parameterAutomation[i] then
                            sp.baseValue = sp.current
                        end
                    end
                    parameterTargetValues[i] = nil -- Stop smoothing for this parameter
                end
            else
                parameterTargetValues[i] = nil -- Remove target if parameter doesn't exist anymore
            end
        end
    end

    -- Update script parameters if any changes were made during smoothing
    if paramsChanged then
        M.helpers.updateScriptParameters(M.scriptParameters, M.script)
    end
end

return M

