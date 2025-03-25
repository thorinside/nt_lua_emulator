-- signal_processor.lua
-- Module for handling signal processing, clock generation, and trigger pulses
local M = {} -- Module table

-- Local state variables
local currentInputs = {}
local currentOutputs = {}
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

    -- Initialize output array
    for i = 1, 8 do currentOutputs[i] = 0 end

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
function M.getInputClock() return inputClock end

-- Get input polarity states
function M.getInputPolarity() return inputPolarity end

-- Get input scaling values
function M.getInputScaling() return inputScaling end

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
function M.updateTriggerPulses()
    for i = 1, 12 do
        if triggerPulseActive[i] then
            local pulseElapsed = time - (triggerPulseTimes[i] or 0)
            if pulseElapsed > triggerPulseDuration then
                triggerPulseActive[i] = false
            end
        end
    end
end

-- Update input values
function M.updateInputs(scriptInputAssignments, script)
    -- Process all 12 physical inputs
    local period = 60 / clockBPM
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
            local baseValue = (phase < halfPeriod) and 5 or 0
            -- Apply scaling to the base value
            currentInputs[i] = baseValue * scale

            -- Process gate inputs by checking which script inputs this physical input is assigned to
            for scriptInputIdx, assignedPhysInput in pairs(
                                                         scriptInputAssignments) do
                if assignedPhysInput == i then
                    -- Found an assignment, check if it's a kGate
                    if type(script.inputs) == "table" and
                        script.inputs[scriptInputIdx] == kGate and script.gate then
                        local prev = prevGateStates[i] or currentInputs[i]
                        if prev ~= currentInputs[i] then
                            local rising = (currentInputs[i] > prev)
                            M.safeScriptCall(script.gate, script,
                                             scriptInputIdx, rising)
                        end
                    end
                end
            end

            prevGateStates[i] = currentInputs[i]
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

            if inputPolarity[i] == kBipolar then
                -- Bipolar mode: -5V to +5V
                currentInputs[i] = 5 * scale * baseValue
                -- Clamp to valid range
                currentInputs[i] = math.max(-5, math.min(5, currentInputs[i]))
            else
                -- Unipolar mode: 0V to +10V
                -- First scale the base value, then shift to unipolar range
                currentInputs[i] = 5 + (5 * scale * baseValue)
                -- Clamp to valid range
                currentInputs[i] = math.max(0, math.min(10, currentInputs[i]))
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
    if type(outputValues) ~= "table" then return false end

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
