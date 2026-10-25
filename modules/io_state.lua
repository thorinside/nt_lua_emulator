-- io_state.lua
-- Module for managing I/O state, mappings, and persistence
local M = {}

-- Required modules
local json = require("lib.dkjson")

-- File path for storing state
local stateFile = "state.json"

-- Track if mappings have changed and need to be saved
local mappingsChanged = false

-- Save current IO mappings to state.json
function M.saveIOState(state, forceWrite)
    -- Only save if mappings have changed or if forcing a write
    if not mappingsChanged and not forceWrite then return true end

    -- Get current window position and size (with safe checks)
    local wx, wy, ww, wh = 0, 0, 768, 600
    if love and love.window then
        if love.window.getPosition then
            wx, wy = love.window.getPosition()
        end
        if love.window.getMode then ww, wh = love.window.getMode() end
    end

    -- Add window position and dimensions to state
    state.window = {x = wx, y = wy, width = ww, height = wh}

    local success, err = M.saveStateFile(state)
    if success then
        print("IO mappings saved to " .. stateFile)
        mappingsChanged = false
    else
        -- Keep dirty state so a later save can retry.
        mappingsChanged = true
        print("Error: Could not save IO mappings: " .. tostring(err))
    end
    return success, err
end

local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function index(n, max) return finite(n) and n % 1 == 0 and n >= 1 and n <= max end
local function sanitize(state)
    for _, key in ipairs({"inputs", "outputs", "parameterAutomation", "inputModes", "parameterValues", "window"}) do
        if type(state[key]) ~= "table" then state[key] = nil end
    end
    for key, max in pairs({inputs = 12, outputs = 8, parameterAutomation = 12}) do
        for k, value in pairs(state[key] or {}) do
            if not index(tonumber(k), 65536) or not index(value, max) then state[key][k] = nil end
        end
    end
    for k, mode in pairs(state.inputModes or {}) do
        if not index(tonumber(k), 12) or type(mode) ~= "table" then state.inputModes[k] = nil
        else
            if type(mode.clock) ~= "boolean" then mode.clock = nil end
            if not finite(mode.polarity) then mode.polarity = nil end
            if not finite(mode.scaling) then mode.scaling = nil end
        end
    end
    for k, value in pairs(state.parameterValues or {}) do
        if not finite(value) then state.parameterValues[k] = nil end
    end
    if not finite(state.clockBPM) or state.clockBPM <= 0 then state.clockBPM = nil end
    for _, key in ipairs({"minimalMode", "oscEnabled"}) do
        if type(state[key]) ~= "boolean" then state[key] = nil end
    end
    local w = state.window
    if w and (not finite(w.x) or not finite(w.y) or not index(w.width, 16384) or not index(w.height, 16384)) then
        state.window = nil
    end
    return state
end

-- Load IO mappings from state.json
function M.loadIOState(scriptPath)
    -- Check if state file exists
    local file = io.open(stateFile, "r")
    if not file then
        print("No saved state found at " .. stateFile)
        return false, nil
    end

    -- Read the file
    local content = file:read("*all")
    file:close()

    -- Parse JSON
    local success, state = pcall(json.decode, content)
    if not success or type(state) ~= "table" then
        print("Error parsing state file")
        return false, nil
    end

    -- Return state even if for a different script
    if state.scriptPath ~= scriptPath then
        print("State is for a different script")
    end

    return true, sanitize(state)
end

-- Create default mappings (first n inputs, first m outputs)
function M.createDefaultMappings(scriptInputCount, scriptOutputCount,
                                 inputAssignments, outputAssignments)
    -- Map first n physical inputs to script inputs
    for i = 1, scriptInputCount do
        if i <= 12 then -- There are 12 physical inputs
            inputAssignments[i] = i
        end
    end

    -- Map first m physical outputs to script outputs
    for i = 1, scriptOutputCount do
        if i <= 8 then -- There are 8 physical outputs
            outputAssignments[i] = i
        end
    end

    -- Mark as changed so it will be saved
    mappingsChanged = true
    print("Created default I/O mappings")

    return inputAssignments, outputAssignments
end

-- Mark that mappings have changed
function M.markMappingsChanged() mappingsChanged = true end

-- Reset mappings changed flag (after loading)
function M.resetMappingsChanged() mappingsChanged = false end

-- Check if mappings have changed
function M.getMappingsChanged() return mappingsChanged end

-- Load state file and return full state object
function M.loadStateFile()
    local file = io.open(stateFile, "r")
    if not file then return {} end

    local content = file:read("*all")
    file:close()

    local success, state = pcall(json.decode, content)
    if not success or type(state) ~= "table" then return {} end

    return state
end

-- Save state file with given state object
function M.saveStateFile(state)
    return require("modules.json_store").save(stateFile, state)
end

-- Export the module
return M
