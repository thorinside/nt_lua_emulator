-- Test script with error fixed
local M = {}

M.inputs = {
    kCV, kCV, kCV, kCV, kCV, kCV
}

M.outputs = {
    kCV, kCV, kCV, kCV
}

function M.init()
    -- Error is now fixed
    local result = 0 + 5  -- No error: valid arithmetic
    print("Script initialized successfully! Result: " .. result)
end

function M.process(inputs, outputs)
    for i = 1, 4 do
        outputs[i] = inputs[i] or 0
    end
end

return M