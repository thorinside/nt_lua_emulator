-- Load with F2. Encoder 1 selects this script's parameter; pot 1 changes it.
-- This exercises metadata, discovery, numeric scaling, enums, and writes.
local algorithm = 0
local selected = 1

return {
    name = "Parameter Info Demo",
    init = function(self)
        algorithm = getCurrentAlgorithm()
        local t = getParameterInfo(algorithm, 1)
        print(t.name, t.min, t.max, t.def, t.unit, t.scaling, t.enumStrings)
        print(t.enumStrings[1]) -- Off
        return {
            inputs = {}, outputs = {},
            parameters = {
                {"Speed", 0, 100, 50, kHz, kBy10},
                {"Mode", {"Off", "On", "Auto"}, 1},
                {"Level", -6000, 0, -1200, kDb, kBy100}
            }
        }
    end,
    encoder1Turn = function(self, delta)
        selected = math.max(1, math.min(getParameterCount(algorithm), selected + delta))
    end,
    pot1Turn = function(self, value)
        setParameterNormalized(algorithm, selected, value)
    end,
    draw = function(self)
        local t = getParameterInfo(algorithm, selected)
        local value = getParameter(algorithm, selected)
        local label = t.enumStrings[value - t.min + 1] or tostring(value)
        drawText(1, 10, getAlgorithmName(algorithm) .. " / " .. t.name)
        drawText(1, 23, "Value: " .. label)
        drawText(1, 36, "Raw range: " .. t.min .. " .. " .. t.max .. "  def: " .. t.def)
        drawText(1, 49, "Unit: " .. t.unit .. "  scaling: " .. t.scaling)
        drawTinyText(1, 62, "Encoder 1: select   Pot 1: change")
        return true
    end
}
