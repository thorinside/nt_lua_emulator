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
    if not mappingsChanged and not forceWrite then return end

    -- Get current window position and size (with safe checks)
    local wx, wy, ww, wh = 0, 0, 768, 600
    if love and love.window then
        if love.window.getPosition then
            wx, wy = love.window.getPosition()
        end
        if love.window.getWidth and love.window.getHeight then
            ww, wh = love.window.getWidth(), love.window.getHeight()
        end
    end

    -- Add window position and dimensions to state
    state.window = {x = wx, y = wy, width = ww, height = wh}

    -- Convert to JSON
    local jsonData = json.encode(state, {indent = true})

    -- Save to file
    local file = io.open(stateFile, "w")
    if file then
        file:write(jsonData)
        file:close()
        print("IO mappings saved to " .. stateFile)
        mappingsChanged = false
    else
        print("Error: Could not save IO mappings to " .. stateFile)
    end
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
    local state = json.decode(content)
    if not state then
        print("Error parsing state file")
        return false, nil
    end

    -- Return state even if for a different script
    if state.scriptPath ~= scriptPath then
        print("State is for a different script")
    end

    return true, state
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
    if not success then return {} end

    return state
end

-- Save state file with given state object
function M.saveStateFile(state)
    local jsonData = json.encode(state, {indent = true})

    local file = io.open(stateFile, "w")
    if file then
        file:write(jsonData)
        file:close()
        return true
    end

    return false
end

-- Export the module
return M
