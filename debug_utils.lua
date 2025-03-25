local emulator = nil

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

return {isDebugMode = isDebugMode, debugLog = debugLog}
