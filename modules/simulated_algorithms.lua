-- Representative preset for testing parameter APIs, not firmware DSP models.
local M = {}

local function parameter(name, min, max, default, unit, scaling, values)
    return {
        name = name, min = min, max = max, default = default, current = default,
        unit = unit or 0, scaling = scaling or 0, enumStrings = values,
        type = values and "enum" or "integer"
    }
end

function M.bypass()
    return parameter("Bypass", 0, 1, 0, 1, 0, {"Off", "On"})
end

function M.create()
    return {
        {name = "EmulatedScript", systemParams = {M.bypass()}, params = {}},
        {name = "Reverb", params = {
            M.bypass(),
            parameter("Mix", 0, 100, 50, 4),
            parameter("Decay", 1, 300, 25, 9, 1),
            parameter("Damping", 20, 20000, 8000, 5),
            parameter("Pre-delay", 0, 500, 0, 8)
        }},
        {name = "Delay", params = {
            M.bypass(),
            parameter("Time", 1, 2000, 250, 8),
            parameter("Feedback", 0, 100, 35, 4),
            parameter("Mix", 0, 100, 50, 4)
        }},
        {name = "Filter", params = {
            M.bypass(),
            parameter("Cutoff", 20, 20000, 1000, 5),
            parameter("Resonance", 0, 100, 0, 4),
            parameter("Type", 0, 3, 0, 1, 0,
                      {"Low-pass", "High-pass", "Band-pass", "Notch"})
        }},
        {name = "VCO", params = {
            M.bypass(),
            parameter("Pitch", -6000, 6000, 0, 6, 2),
            parameter("Waveform", 0, 4, 0, 1, 0,
                      {"Sine", "Triangle", "Saw", "Square", "Pulse"}),
            parameter("PWM", 0, 100, 50, 4)
        }}
    }
end

return M
