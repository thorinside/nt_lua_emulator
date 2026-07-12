-- Test script with intentional error
local M = {}

M.inputs = {
    kCV, kCV, kCV, kCV, kCV, kCV
}

M.outputs = {
    kCV, kCV, kCV, kCV
}

function M.init()
    -- This will cause an error
    local result = nil + 5  -- Error: attempt to perform arithmetic on nil value
end

function M.process(inputs, outputs)
    for i = 1, 4 do
        outputs[i] = inputs[i] or 0
    end
end

return M