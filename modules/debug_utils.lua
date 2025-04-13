local emulator = nil

-- Get UI State for debug checking
local uiState = require("modules.ui_state")

-- Try to load emulator module for debug mode access
local function loadEmulator()
    if not emulator then pcall(function() emulator = require("emulator") end) end
end

-- Check if debug mode is enabled
local function isDebugMode()
    loadEmulator()
    if emulator and emulator.isDebugMode then return emulator.isDebugMode() end
    return false
end

-- Debug log function that only prints if debug mode is enabled
local function debugLog(...) if isDebugMode() then print("[DEBUG]", ...) end end

local debug_utils = {}
local debugFile = nil

-- Log a debug message
local function mainDebugLog(...) -- Accept variable arguments
    -- Check uiState directly
    if uiState and uiState.isDebugMode and uiState.isDebugMode() then
        local timeStr = os.date("%Y-%m-%d %H:%M:%S")
        -- Concatenate all arguments into a single string
        local messageContent = table.concat({...}, " ")
        local logMessage = timeStr .. " - " .. messageContent
        print(logMessage)
        if debugFile then
            debugFile:write(logMessage .. "\n")
            debugFile:flush()
        end
    end
end

-- Control garbage collection behavior
function debug_utils.setGCMode(mode, param)
    mode = mode or "setstepmul"
    param = param or 200 -- Default is fairly aggressive

    if mode == "setstepmul" then
        -- Controls how aggressive GC is (higher = more aggressive)
        -- Default is 200 (recommended range 100-400)
        collectgarbage(mode, param)
        debug_utils.debugLog("Set GC step multiplier to " .. param)
    elseif mode == "setpause" then
        -- Controls how much memory growth triggers GC (higher = less frequent)
        -- Default is 100 (as a percentage of current use)
        collectgarbage(mode, param)
        debug_utils.debugLog("Set GC pause to " .. param .. "%")
    else
        debug_utils.debugLog("Unknown GC mode: " .. mode)
    end
end

-- Assign the modified function back to the module export
debug_utils.debugLog = mainDebugLog

return debug_utils
