-- Test script for MIDI output functionality
-- Tests the sendMIDI() function with various message types

local testScript = {}

-- Define inputs and outputs
testScript.inputs = {}
testScript.outputs = {}

-- Test counter for cycling through different MIDI messages
local testCounter = 0
local testInterval = 120 -- Test every 2 seconds at 60fps

function testScript.init()
    print("MIDI Output Test Script initialized")
    print("This script will send various MIDI messages to test sendMIDI() function")
end

function testScript.process(inputs, outputs)
    testCounter = testCounter + 1
    
    if testCounter >= testInterval then
        testCounter = 0
        
        -- Cycle through different test cases
        local testCase = math.floor(love.timer.getTime()) % 8
        
        if testCase == 0 then
            -- Test Note On: Channel 1, Middle C, Velocity 127
            print("Testing Note On: Channel 1, Note 60, Velocity 127")
            sendMIDI(0, 0x90, 60, 127)
            
        elseif testCase == 1 then
            -- Test Note Off: Channel 1, Middle C
            print("Testing Note Off: Channel 1, Note 60, Velocity 0")
            sendMIDI(0, 0x80, 60, 0)
            
        elseif testCase == 2 then
            -- Test Control Change: Channel 1, Volume, Value 100
            print("Testing Control Change: Channel 1, CC 7 (Volume), Value 100")
            sendMIDI(0, 0xB0, 7, 100)
            
        elseif testCase == 3 then
            -- Test Program Change: Channel 1, Program 42
            print("Testing Program Change: Channel 1, Program 42")
            sendMIDI(0, 0xC0, 42)
            
        elseif testCase == 4 then
            -- Test System Real-time: MIDI Clock
            print("Testing System Real-time: MIDI Clock")
            sendMIDI(0, 0xF8)
            
        elseif testCase == 5 then
            -- Test invalid parameters (should fail gracefully)
            print("Testing invalid parameters (should log error)")
            sendMIDI(0, 256) -- Invalid status byte > 255
            
        elseif testCase == 6 then
            -- Test invalid data byte (should fail gracefully)
            print("Testing invalid data byte (should log error)")
            sendMIDI(0, 0x90, 128, 127) -- Invalid data byte > 127
            
        elseif testCase == 7 then
            -- Test too many arguments (should fail gracefully)
            print("Testing too many arguments (should log error)")
            sendMIDI(0, 0x90, 60, 127, 99) -- Too many arguments
        end
    end
end

return testScript