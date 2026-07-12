-- Test script with intentional syntax error for testing error clearing
-- This script should fail to load initially, then be fixed to test error clearing behavior

-- Step 1: Uncomment the following line to create a syntax error
syntax_error_here = function(

-- Step 2: To fix, comment out the above line and uncomment the working script below:

--[[
-- Working test script for error clearing verification
local script = {}

function script.init()
    print("Test script loaded successfully - errors should be cleared!")
end

script.inputs = {}
script.outputs = {}

function script.process(inputs, outputs)
    -- Simple passthrough
    for i = 1, #inputs do
        if outputs[i] then
            outputs[i] = inputs[i]
        end
    end
end

function script.draw()
    drawText(10, 10, "Error clearing test - SUCCESS!")
end

return script
--]]