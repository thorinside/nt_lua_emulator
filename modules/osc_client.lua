-- osc_client.lua
local osc = require("modules.osc")
local config = require("modules.config")
local debug_utils = require("modules.debug_utils")

-- This might be undefined if emulator.lua isn't loaded yet
local emulator

local osc_client = {}

local client = nil
local lastSendTime = 0
local currentConfig = nil
local script = nil
local enabled = false -- Track OSC enabled state

-- Check for emulator debug mode
local function isDebugMode()
    if emulator and emulator.isDebugMode and emulator.isDebugMode() then
        return true
    end
    return false
end

-- Helper function to log debug information
local function debugLog(...) debug_utils.debugLog("[OSC]", ...) end

-- Initialize the OSC client
function osc_client.init()
    -- Try to load emulator for debug access
    if not emulator then
        pcall(function() emulator = require("modules.emulator") end)
    end

    -- Enable OSC detailed debugging if emulator debug mode is on
    if isDebugMode() then
        debugLog("Enabling detailed OSC debugging")
        if osc.enableDebug then osc.enableDebug(true) end
    end

    currentConfig = config.load()
    if not currentConfig.osc.enabled then
        print("OSC is disabled in config")
        return
    end

    -- Create OSC client
    client = osc.new(currentConfig.osc.host, currentConfig.osc.port)
    enabled = true
    print(string.format("OSC client initialized: %s:%d", currentConfig.osc.host,
                        currentConfig.osc.port))
end

-- Toggle OSC on/off
function osc_client.toggle()
    -- Make sure config is loaded
    if not currentConfig then currentConfig = config.load() end

    if enabled then
        -- Disable OSC
        if client then
            client:close()
            client = nil
        end
        enabled = false
        print("OSC disabled")
    else
        -- Re-enable OSC regardless of config setting
        -- Update OSC debug status
        if isDebugMode() and osc.enableDebug then osc.enableDebug(true) end

        local host = "127.0.0.1"
        local port = 8000

        -- Use config values if available
        if currentConfig and currentConfig.osc then
            host = currentConfig.osc.host or host
            port = currentConfig.osc.port or port
        end

        client = osc.new(host, port)
        enabled = true
        print(string.format("OSC enabled: %s:%d", host, port))
    end
end

-- Check if OSC is currently enabled
function osc_client.isEnabled() return enabled end

-- Set the current script to get output names
function osc_client.setScript(newScript) script = newScript end

-- Convert a string to OSC-friendly format (spaces to underscores)
local function toOSCName(str) return str:gsub("%s+", "_") end

-- Get the OSC address for an output
local function getOutputAddress(index)
    local baseAddress = currentConfig.osc.address
    if not baseAddress then baseAddress = "/dnt" end
    -- Ensure address is a string and starts with /
    baseAddress = tostring(baseAddress)
    if not baseAddress:match("^/") then baseAddress = "/" .. baseAddress end
    -- Add slash between base address and channel number
    return baseAddress .. "/" .. index
end

-- Send output values via OSC
function osc_client.sendOutputs(outputs)
    if not client or not enabled then return end

    local currentTime = love.timer.getTime()
    if currentTime - lastSendTime < currentConfig.osc.sendInterval then
        return -- Don't send too frequently
    end

    lastSendTime = currentTime

    local address = currentConfig.osc.address or "/dnt"
    address = tostring(address) -- Ensure address is a string
    if not address:match("^/") then address = "/" .. address end

    -- Debug output summary if enabled
    if debug_utils.isDebugMode() then
        debugLog("Sending OSC values:", #outputs, "outputs")
        for i, value in ipairs(outputs) do
            local outputAddress = getOutputAddress(i)
            debugLog(string.format("  %s = %.6f", outputAddress, value))
        end
    end

    if currentConfig.osc.outputFormat == "array" then
        -- Send all outputs as a single message with multiple arguments
        -- Ensure we have at least one argument
        if #outputs == 0 then outputs = {0} end
        -- Send all values in a single message using send_float
        for i, value in ipairs(outputs) do
            client.send_float(address, value)
            debugLog("Sent float to", address, "=", value)
        end
    else
        -- Send individual messages for each output
        for i, value in ipairs(outputs) do
            local outputAddress = getOutputAddress(i)
            client.send_float(outputAddress, value)
            debugLog("Sent float to", outputAddress, "=", value)
        end
    end
end

-- Update configuration
function osc_client.updateConfig(newConfig)
    currentConfig = newConfig

    -- Reinitialize client if settings changed
    if client then
        client:close()
        client = nil
    end

    if currentConfig.osc.enabled then osc_client.init() end
end

-- Clean up
function osc_client.cleanup()
    if client then
        client:close()
        client = nil
    end
    enabled = false
end

return osc_client
