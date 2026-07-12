local printed = {}
local activeFont

local function font(widthPerCharacter, height)
    return {
        getWidth = function(_, text)
            return #text * widthPerCharacter
        end,
        getHeight = function()
            return height
        end
    }
end

love = {
    graphics = {
        newCanvas = function()
            return {}
        end,
        setDefaultFilter = function() end,
        newFont = function(path)
            if path:find("tom%-thumb") then
                return font(8, 24)
            end
            return font(20, 32)
        end,
        push = function() end,
        pop = function() end,
        setColor = function() end,
        setFont = function(value)
            activeFont = value
        end,
        print = function(text, x, y)
            printed[#printed + 1] = {
                text = text,
                x = x,
                y = y,
                font = activeFont
            }
        end
    }
}

local display = require("modules.display")
display.init()

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, expected,
                            actual), 2)
    end
end

local function assertPrint(index, expectedX, expectedY, message)
    local call = printed[index]
    assertEqual(call.x, expectedX, message .. " x")
    assertEqual(call.y, expectedY, message .. " baseline")
end

display.drawText(100, 40, "abcd")
display.drawText(100, 40, "abcd", 8, "centre")
display.drawText(100, 40, "abcd", 8, "right")
display.drawTinyText(100, 40, "abcd", 15, "centre")
display.drawTinyText(100, 40, "abcd", 15, "right")

-- Coordinates passed to LÖVE are scaled by four. The mock regular font is 80
-- scaled pixels wide and the tiny font is 32 scaled pixels wide.
assertPrint(1, 400, 128, "default left alignment")
assertPrint(2, 360, 128, "regular centre alignment")
assertPrint(3, 320, 128, "regular right alignment")
assertPrint(4, 384, 136, "tiny centre alignment")
assertPrint(5, 368, 136, "tiny right alignment")

print("text formatting tests passed")
