-- midi_handler.lua
-- Optional MIDI support module that gracefully handles missing MIDI library
local M = {}

-- Local state
local midi = nil
local midiAvailable = false
local currentInputPort = nil
local inputPortIndex = -1

-- Try to load MIDI library
function M.init()
    -- Attempt to load luamidi library
    local success, result = pcall(require, "luamidi")
    if success then
        midi = result
        midiAvailable = true
        print("MIDI support loaded successfully")
        return true
    else
        -- Try alternative name
        success, result = pcall(require, "midi")
        if success then
            midi = result
            midiAvailable = true
            print("MIDI support loaded successfully (midi)")
            return true
        else
            print("MIDI support not available: " .. tostring(result))
            midiAvailable = false
            return false
        end
    end
end

-- Check if MIDI support is available
function M.isAvailable()
    return midiAvailable
end

-- Get list of available MIDI input ports
function M.getInputPorts()
    if not midiAvailable or not midi then
        return {}
    end
    
    local ports = {}
    local count = midi.getinportcount()
    
    for i = 0, count - 1 do
        local name = midi.getInPortName(i)
        if name then
            table.insert(ports, {
                index = i,
                name = name
            })
        else
            -- Fallback if getInPortName doesn't exist
            table.insert(ports, {
                index = i,
                name = "MIDI Input " .. (i + 1)
            })
        end
    end
    
    return ports
end

-- Open a MIDI input port
function M.openInputPort(portIndex)
    if not midiAvailable or not midi then
        return false
    end
    
    -- Close current port if open
    M.close()
    
    -- Validate port index
    local portCount = midi.getinportcount()
    if portIndex < 0 or portIndex >= portCount then
        print("Invalid MIDI port index: " .. portIndex)
        return false
    end
    
    -- Open the port
    local success = true
    if midi.openin then
        success = midi.openin(portIndex)
    end
    
    if success then
        currentInputPort = portIndex
        inputPortIndex = portIndex
        print("Opened MIDI input port " .. portIndex)
        return true
    else
        print("Failed to open MIDI input port " .. portIndex)
        return false
    end
end

-- Poll for MIDI messages
function M.pollMessages()
    if not midiAvailable or not midi or inputPortIndex < 0 then
        return nil
    end
    
    -- Check for messages
    if midi.getMessage then
        local a, b, c, d = midi.getMessage(inputPortIndex)
        if a then
            -- MIDI message received
            -- Return as a table matching script expectation (only first 3 bytes)
            return {a, b, c}
        end
    end
    
    return nil
end

-- Close current MIDI input
function M.close()
    if not midiAvailable or not midi then
        return
    end
    
    if currentInputPort and midi.closein then
        midi.closein(currentInputPort)
        print("Closed MIDI input port " .. currentInputPort)
    end
    
    currentInputPort = nil
    inputPortIndex = -1
end

-- Get current input port index
function M.getCurrentPortIndex()
    return inputPortIndex
end

-- Helper to extract MIDI channel from status byte
function M.getChannelFromStatus(status)
    if not status then return nil end
    -- MIDI channels are in lower 4 bits of status byte
    -- Convert from 0-15 to 1-16
    return (status % 16) + 1
end

-- Helper to check if a MIDI message is a note message
function M.isNoteMessage(status)
    if not status then return false end
    local messageType = math.floor(status / 16)
    -- 0x80 = note off, 0x90 = note on
    return messageType == 8 or messageType == 9
end

return M