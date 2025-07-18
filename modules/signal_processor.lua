-- signal_processor.lua
-- Module for handling signal processing, clock generation, and trigger pulses
local M = {} -- Module table

-- Local state variables
local currentInputs = {}
local currentOutputs = {} -- Will be replaced with shared reference
local inputClock = {}
local inputPolarity = {}
local inputScaling = {}
local prevGateStates = {}
local clockBPM = 110 -- Default BPM
local minBPM = 30
local maxBPM = 200
local time = 0

-- Trigger pulse visualization
local triggerPulseActive = {}
local triggerPulseTimes = {}
local triggerPulseDuration = 0.1 -- 100ms pulse duration

-- Initialize the signal processor
function M.init(deps)
    -- Store dependencies
    M.safeScriptCall = deps.safeScriptCall
    M.scriptManager = deps.scriptManager
    
    -- Use shared currentOutputs from emulator
    if deps.currentOutputs then
        currentOutputs = deps.currentOutputs
    end

    -- Initialize input arrays with default values
    for i = 1, 12 do
        inputClock[i] = false
        inputPolarity[i] = kBipolar -- bipolar by default
        inputScaling[i] = 1.0 -- default scaling factor (1.0 = no scaling)
        prevGateStates[i] = 0
        triggerPulseActive[i] = false
        triggerPulseTimes[i] = 0
        currentInputs[i] = 0
    end

    -- Initialize output array if not using shared reference
    if not deps.currentOutputs then
        for i = 1, 8 do currentOutputs[i] = 0 end
    end

    return M
end

-- Update the time counter
function M.updateTime(dt)
    time = time + dt
    return time
end

-- Get current time value
function M.getTime() return time end

-- Set clock BPM
function M.setClockBPM(bpm)
    -- Handle nil, NaN, or non-numeric values
    if bpm == nil or type(bpm) ~= "number" or bpm ~= bpm then -- bpm ~= bpm checks for NaN
        -- Fall back to default BPM
        clockBPM = 110
        return clockBPM
    end

    -- Ensure BPM is within range
    clockBPM = math.max(minBPM, math.min(maxBPM, bpm))
    return clockBPM
end

-- Get clock BPM
function M.getClockBPM() return clockBPM end

-- Get BPM range
function M.getBPMRange() return minBPM, maxBPM end

-- Get current inputs
function M.getCurrentInputs() return currentInputs end

-- Get current outputs
function M.getCurrentOutputs() return currentOutputs end

-- Get input clock states
function M.getInputClock(inputIndex)
    if inputIndex and inputIndex >= 1 and inputIndex <= 12 then
        return inputClock[inputIndex]
    end
    return nil -- Or false? Return nil for invalid index.
end

-- Get input polarity states
function M.getInputPolarity(inputIndex)
    if inputIndex and inputIndex >= 1 and inputIndex <= 12 then
        return inputPolarity[inputIndex]
    end
    return nil -- Return nil for invalid index.
end

-- Get input scaling values
function M.getInputScaling(inputIndex)
    if inputIndex and inputIndex >= 1 and inputIndex <= 12 then
        return inputScaling[inputIndex]
    end
    return nil -- Return nil for invalid index.
end

-- Get entire input state tables (for drawing/saving)
function M.getInputClockTable() return inputClock end
function M.getInputPolarityTable() return inputPolarity end
function M.getInputScalingTable() return inputScaling end

-- Set input clock for an input
function M.setInputClock(inputIndex, enabled)
    if inputIndex < 1 or inputIndex > 12 then return false end
    inputClock[inputIndex] = enabled
    return true
end

-- Set input polarity for an input
function M.setInputPolarity(inputIndex, polarity)
    if inputIndex < 1 or inputIndex > 12 then return false end
    if polarity ~= kBipolar and polarity ~= kUnipolar then return false end
    inputPolarity[inputIndex] = polarity
    return true
end

-- Set input scaling for an input
function M.setInputScaling(inputIndex, scaling)
    if inputIndex < 1 or inputIndex > 12 then return false end
    inputScaling[inputIndex] = math.max(0.0, math.min(1.0, scaling))
    return true
end

-- Cycle input mode (bipolar -> clock -> unipolar -> bipolar)
function M.cycleInputMode(inputIndex)
    if inputIndex < 1 or inputIndex > 12 then return false end

    if inputPolarity[inputIndex] == kBipolar and not inputClock[inputIndex] then
        -- From bipolar -> clock mode
        inputClock[inputIndex] = true
        return "clock"
    elseif inputClock[inputIndex] then
        -- From clock -> unipolar mode
        inputClock[inputIndex] = false
        inputPolarity[inputIndex] = kUnipolar
        return "unipolar"
    else
        -- From unipolar -> bipolar (default)
        inputPolarity[inputIndex] = kBipolar
        inputClock[inputIndex] = false
        return "bipolar"
    end
end

-- Reset an input to default settings
function M.resetInput(inputIndex)
    if inputIndex < 1 or inputIndex > 12 then return false end

    inputClock[inputIndex] = false
    inputPolarity[inputIndex] = kBipolar
    inputScaling[inputIndex] = 1.0
    prevGateStates[inputIndex] = 0

    return true
end

-- Trigger a pulse on an input
function M.triggerPulse(inputIndex)
    if inputIndex < 1 or inputIndex > 12 then return false end

    triggerPulseActive[inputIndex] = true
    triggerPulseTimes[inputIndex] = time

    return true
end

-- Update trigger pulse states
function M.updateTriggerPulses(scriptInputAssignments, script, scriptOutputAssignments)
    for i = 1, 12 do
        if triggerPulseActive[i] then
            local pulseElapsed = time - (triggerPulseTimes[i] or 0)
            if pulseElapsed > triggerPulseDuration then
                triggerPulseActive[i] = false
            end

            -- Find which script inputs this physical input is assigned to
            if script and type(script.inputs) == "table" then
                for scriptInputIdx, assignedPhysInput in pairs(
                                                             scriptInputAssignments) do
                    if assignedPhysInput == i and script.inputs[scriptInputIdx] ==
                        kTrigger then
                        -- This is a newly activated trigger input, call the trigger function
                        -- Only call during the first frame of the pulse
                        if pulseElapsed < 0.02 then
                            -- Ensure we pass the script input index (not the physical input)
                            local outputValues = nil
                            if M.scriptManager then
                                outputValues = M.scriptManager
                                                   .callScriptTrigger({
                                    input = scriptInputIdx
                                })
                            else
                                -- Direct call with script input index
                                outputValues =
                                    M.safeScriptCall(script.trigger, script,
                                                     scriptInputIdx)
                            end
                            -- Process the returned output values
                            M.updateOutputs(outputValues, scriptOutputAssignments)
                        end
                    end
                end
            end
        end
    end
end

-- Update input values
function M.updateInputs(scriptInputAssignments, script, scriptOutputAssignments)
    -- Process all 12 physical inputs
    -- Ensure clockBPM is never zero to prevent division by zero
    local safeBPM = math.max(minBPM, clockBPM)
    local period = 60 / safeBPM
    local halfPeriod = period / 2

    -- Determine which physical inputs are connected to script inputs and their types
    local physInputToScriptType = {}
    if type(script.inputs) == "table" then
        for scriptInputIdx, assignedPhysInput in pairs(scriptInputAssignments) do
            if assignedPhysInput and script.inputs[scriptInputIdx] then
                physInputToScriptType[assignedPhysInput] =
                    script.inputs[scriptInputIdx]
            end
        end
    end

    for i = 1, 12 do
        local inputType = physInputToScriptType[i]
        local scale = inputScaling[i] or 1.0

        if inputClock[i] then
            -- Clock mode - generate gate signals based on BPM
            local phase = time % period
            -- Store current clock state (high or low)
            local clockState = (phase < halfPeriod)
            local baseValue = clockState and 5 or 0
            -- Apply scaling to the base value
            local newValue = baseValue * scale

            -- Process gate inputs by checking which script inputs this physical input is assigned to
            for scriptInputIdx, assignedPhysInput in pairs(
                                                         scriptInputAssignments) do
                if assignedPhysInput == i then
                    -- Found an assignment, check if it's a kGate
                    if type(script.inputs) == "table" and
                        script.inputs[scriptInputIdx] == kGate and script.gate then
                        -- Get previous clock state (true = high, false = low)
                        local prevClockState = prevGateStates[i] > 2.5
                        -- Detect rising and falling edges based on clock state
                        if prevClockState ~= clockState then
                            -- Debug output to verify gate transitions
                            local rising = clockState -- true when going from low to high

                            -- We need to ensure the parameters are passed correctly and consistently
                            local outputValues = nil
                            if M.scriptManager then
                                -- For script manager version, ensure we\'re passing the parameters correctly
                                outputValues =
                                    M.scriptManager.callScriptGate({
                                        input = scriptInputIdx,
                                        rising = rising
                                    })
                            else
                                -- Direct call - must ensure parameters are in the right order (script obj, input, rising)
                                outputValues =
                                    M.safeScriptCall(script.gate, script,
                                                     scriptInputIdx, rising)
                            end
                            -- Process the returned output values
                            M.updateOutputs(outputValues, scriptOutputAssignments)
                        end
                    end
                end
            end

            -- Update values after all script inputs are processed
            currentInputs[i] = newValue
            prevGateStates[i] = newValue
        elseif inputType == kTrigger then
            -- Trigger input - show pulse when active
            if triggerPulseActive[i] then
                currentInputs[i] = 10.0 * scale -- High voltage during pulse, scaled
            else
                currentInputs[i] = 0.0 -- Zero when inactive
            end
        else
            -- CV mode - generate continuous values with sine waves
            local baseValue = math.sin(time + i)

            -- Clamp the base value to the range of the input polarity
            if inputPolarity[i] == kBipolar then
                baseValue = baseValue * 5.0
                baseValue = math.max(-5, math.min(5, baseValue))
            else
                baseValue = ((baseValue + 1.0) / 2.0) * 10.0
                baseValue = math.max(0, math.min(10, baseValue))
            end

            if scale == 0 then
                currentInputs[i] = 0
            else
                currentInputs[i] = scale * baseValue
            end
        end
    end

    return currentInputs
end

-- Prepare script input values from physical inputs
function M.prepareScriptInputValues(scriptInputCount, scriptInputAssignments)
    local scriptInputValues = {}

    -- For each script input, look for an assigned physical input and get its value
    for i = 1, scriptInputCount do
        local physicalInput = scriptInputAssignments[i]
        if physicalInput then
            scriptInputValues[i] = currentInputs[physicalInput]
        else
            scriptInputValues[i] = 0 -- Default value if no physical input is assigned
        end
    end

    return scriptInputValues
end

-- Reset outputs that aren't connected to any script output
function M.resetUnconnectedOutputs(scriptOutputAssignments)
    -- Reset all physical outputs that aren't connected to any script output
    local connectedOutputs = {}
    for _, physOutput in pairs(scriptOutputAssignments) do
        connectedOutputs[physOutput] = true
    end

    -- Reset any output not in the connected list to 0V
    for i = 1, 8 do -- 8 physical outputs
        if not connectedOutputs[i] then currentOutputs[i] = 0 end
    end
end

-- Update outputs with values from script
function M.updateOutputs(outputValues, scriptOutputAssignments)
    -- If outputValues is not a table, just return current outputs unchanged
    -- This supports the behavior where returning nil keeps previous values
    if type(outputValues) ~= "table" then return currentOutputs end

    for slot, value in ipairs(outputValues) do
        if value ~= nil then
            local mappedOutput = scriptOutputAssignments[slot]
            if mappedOutput then
                currentOutputs[mappedOutput] = value
            else
                -- Default to the same-numbered physical output if available.
                if slot <= 8 then currentOutputs[slot] = value end
            end
        end
    end

    return currentOutputs
end

-- Direct output setting
function M.setOutput(outputIndex, value)
    if outputIndex < 1 or outputIndex > 8 then return false end
    currentOutputs[outputIndex] = value
    return true
end

-- Get trigger pulse states
function M.getTriggerPulseStates()
    return {
        active = triggerPulseActive,
        times = triggerPulseTimes,
        duration = triggerPulseDuration
    }
end

return M
