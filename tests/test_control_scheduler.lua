local scheduler = require("modules.control_scheduler").new(0.001, 100)
local calls = {}

local steps = scheduler:advance(0.0165, function(dt)
    calls[#calls + 1] = dt
end)
if steps ~= 16 or #calls ~= 16 then
    error("16.5 ms should schedule 16 control steps")
end
for _, dt in ipairs(calls) do
    if dt ~= 0.001 then error("control step dt must be exactly 1 ms") end
end

steps = scheduler:advance(0.0005, function(dt)
    calls[#calls + 1] = dt
end)
if steps ~= 1 then error("fractional time should carry into the next frame") end

steps = scheduler:advance(5, function() end)
if steps ~= 100 then error("catch-up must be bounded to 100 steps") end

scheduler:reset()
if scheduler.accumulator ~= 0 then error("reset must clear accumulated time") end

print("1 kHz control scheduler tests passed")
