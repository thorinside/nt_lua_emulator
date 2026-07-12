local rectangles = {}
local circles = {}
local lines = {}

local function mockFont()
    return {
        getWidth = function() return 0 end,
        getHeight = function() return 0 end
    }
end

love = {
    graphics = {
        newCanvas = function() return {} end,
        setDefaultFilter = function() end,
        newFont = mockFont,
        push = function() end,
        pop = function() end,
        setColor = function() end,
        rectangle = function(...)
            rectangles[#rectangles + 1] = {...}
        end,
        circle = function(...)
            circles[#circles + 1] = {...}
        end,
        line = function(...)
            lines[#lines + 1] = {...}
        end,
        points = function() end
    }
}

local display = require("modules.display")
display.init({scaling = 4})

display.drawRectangle(1.9, 2.9, 5.9, 8.9, 15)
display.drawBox(1.9, 2.9, 5.9, 8.9, 15)
display.drawLine(1.9, 2.9, 5.9, 8.9, 15)
display.drawCircle(10.9, 11.9, 3.9, 15)
display.drawSmoothCircle(10.9, 11.9, 3.9, 15)

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, expected,
                            actual), 2)
    end
end

assertEqual(rectangles[1][1], "fill", "filled rectangle mode")
assertEqual(rectangles[1][2], 4, "rectangle integer x")
assertEqual(rectangles[1][3], 8, "rectangle integer y")
assertEqual(rectangles[2][1], "line", "box mode")
assertEqual(lines[1][1], 4, "line integer x1")
assertEqual(lines[1][4], 32, "line integer y2")
assertEqual(circles[1][2], 40, "circle integer x")
assertEqual(circles[1][4], 12, "circle integer radius")
assertEqual(circles[2][2], 43.6, "smooth circle fractional x")
assertEqual(circles[2][4], 15.6, "smooth circle fractional radius")

print("drawing primitive tests passed")
