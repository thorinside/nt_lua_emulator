-- text_alignment_test.lua
-- Integration test for text alignment functionality in the Disting NT Emulator
-- Load this script with F2 to test the new drawText/drawTinyText alignment features

local test = {}

-- Test parameters
local frameCounter = 0
local testPhase = 1
local maxPhases = 4

-- Test configurations
local tests = {
    {name = "Left Alignment", alignment = "left"},
    {name = "Centre Alignment", alignment = "centre"},
    {name = "Right Alignment", alignment = "right"},
    {name = "Backward Compatibility", alignment = nil}
}

function test.init()
    print("Text Alignment Test Script Initialized")
    frameCounter = 0
    testPhase = 1
end

function test.process(inputs, outputs)
    -- Simple test - no audio processing needed
    for i = 1, 4 do
        outputs[i] = 0
    end
end

function test.render()
    -- Clear the display first
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Update test phase every 120 frames (about 2 seconds at 60fps)
    frameCounter = frameCounter + 1
    if frameCounter > 120 then
        frameCounter = 0
        testPhase = testPhase + 1
        if testPhase > maxPhases then
            testPhase = 1
        end
    end
    
    local currentTest = tests[testPhase]
    
    -- Title
    drawText(128, 10, "Text Alignment Test", 15, "centre")
    drawText(128, 20, "Phase " .. testPhase .. ": " .. currentTest.name, 10, "centre")
    
    -- Reference lines for alignment testing
    local testX = 128  -- Center of display
    drawLine(testX, 0, testX, 64, 3)  -- Vertical reference line
    drawText(testX + 5, 45, "X=" .. testX, 8)
    
    -- Regular text tests
    local regularY = 35
    if currentTest.alignment then
        drawText(testX, regularY, "Regular Text", 15, currentTest.alignment)
        drawText(testX + 60, regularY, "(" .. currentTest.alignment .. ")", 8)
    else
        -- Test backward compatibility (no alignment parameter)
        drawText(testX, regularY, "Regular Text", 15)
        drawText(testX + 60, regularY, "(default)", 8)
    end
    
    -- Tiny text tests  
    local tinyY = 50
    if currentTest.alignment then
        drawTinyText(testX, tinyY, "Tiny Text Sample", 12, currentTest.alignment)
        drawTinyText(testX + 80, tinyY, "(" .. currentTest.alignment .. ")", 6)
    else
        -- Test backward compatibility (no alignment parameter)
        drawTinyText(testX, tinyY, "Tiny Text Sample", 12)
        drawTinyText(testX + 80, tinyY, "(default)", 6)
    end
    
    -- Additional alignment demonstrations on left and right sides
    local leftX = 50
    local rightX = 200
    
    -- Left side tests
    drawLine(leftX, 25, leftX, 60, 2)
    if currentTest.alignment then
        drawText(leftX, 30, "L", 10, currentTest.alignment)
        drawTinyText(leftX, 40, "l", 8, currentTest.alignment)
    else
        drawText(leftX, 30, "L", 10)
        drawTinyText(leftX, 40, "l", 8)
    end
    
    -- Right side tests
    drawLine(rightX, 25, rightX, 60, 2)
    if currentTest.alignment then
        drawText(rightX, 30, "R", 10, currentTest.alignment)
        drawTinyText(rightX, 40, "r", 8, currentTest.alignment)
    else
        drawText(rightX, 30, "R", 10)
        drawTinyText(rightX, 40, "r", 8)
    end
    
    -- Progress indicator
    local progress = (frameCounter / 120) * 256
    fillRectangle(0, 62, progress, 64, 5)
end

-- Input/output definitions
test.inputs = {}
test.outputs = {}

-- Control callbacks for manual testing
function test.button1Pressed()
    testPhase = testPhase + 1
    if testPhase > maxPhases then
        testPhase = 1
    end
    frameCounter = 0
    print("Switched to test phase: " .. testPhase .. " (" .. tests[testPhase].name .. ")")
end

function test.button2Pressed()
    testPhase = testPhase - 1
    if testPhase < 1 then
        testPhase = maxPhases
    end
    frameCounter = 0
    print("Switched to test phase: " .. testPhase .. " (" .. tests[testPhase].name .. ")")
end

function test.encoderPressed()
    print("Text alignment test results:")
    print("- Left alignment: Text should start at reference line")
    print("- Centre alignment: Text should be centered on reference line") 
    print("- Right alignment: Text should end at reference line")
    print("- Backward compatibility: Should work like left alignment")
    print("Press Button 1/2 to cycle through test phases")
end

return test