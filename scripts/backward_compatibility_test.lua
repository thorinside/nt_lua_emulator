-- backward_compatibility_test.lua
-- Test to verify that existing scripts still work with the new text alignment feature

local backwardTest = {}

function backwardTest.init()
    print("Backward Compatibility Test Initialized")
end

function backwardTest.process(inputs, outputs)
    -- No processing needed for this test
    for i = 1, 4 do
        outputs[i] = 0
    end
end

function backwardTest.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Title using old 4-parameter signature
    drawText(10, 10, "Backward Compatibility Test", 15)
    drawTinyText(10, 20, "Testing old 4-parameter signature", 12)
    
    -- Test various text positions using old signature
    drawText(10, 35, "Regular Text Old Style", 10)
    drawTinyText(10, 45, "Tiny Text Old Style", 8)
    
    -- Test with color variations
    drawText(10, 55, "Color Test", 5)
    drawTinyText(150, 55, "Tiny Color", 3)
    
    -- Test edge case: empty text
    drawText(200, 35, "", 15)
    drawTinyText(200, 45, "", 12)
    
    -- Status indicator
    drawText(200, 10, "PASS", 15)
    drawTinyText(200, 20, "4-param", 10)
end

-- Input/output definitions
backwardTest.inputs = {}
backwardTest.outputs = {}

return backwardTest