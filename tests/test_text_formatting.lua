local printed = {}
local activeFont
local activeCanvas
local stack = {}
local failNextPrint = false

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
        push = function()
            stack[#stack + 1] = {canvas = activeCanvas, font = activeFont}
        end,
        pop = function()
            local saved = assert(table.remove(stack), "graphics stack underflow")
            activeCanvas, activeFont = saved.canvas, saved.font
        end,
        getStackDepth = function() return #stack end,
        getCanvas = function() return activeCanvas end,
        setCanvas = function(canvas) activeCanvas = canvas end,
        clear = function() end,
        setColor = function() end,
        setFont = function(value)
            activeFont = value
        end,
        print = function(text, x, y)
            assert(type(text) == "string", "text must be converted before drawing")
            if failNextPrint then
                failNextPrint = false
                error("simulated drawing failure")
            end
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

-- Metadata values can be drawn directly, with or without alignment. Missing
-- enum entries must not pass nil to LÖVE or its font-width calculations.
for _, draw in ipairs({display.drawText, display.drawTinyText}) do
    for _, alignment in ipairs({"left", "centre", "right"}) do
        for _, value in ipairs({0, 1, -100, 2.5}) do
            draw(150, 12, value, 15, alignment)
            assertEqual(printed[#printed].text, tostring(value), "numeric text")
        end
        draw(150, 12, nil, 15, alignment)
        assertEqual(printed[#printed].text, "", "missing enum entry")
    end
end
assertEqual(#stack, 0, "balanced text drawing")

-- A caught drawing error used to leave an extra push on the stack. The outer
-- pop restored an active canvas and the application crashed in present().
-- The loader replaces global debug with a logger after display is required.
local originalDebug = debug
debug = function() end
local callerCanvas = {}
love.graphics.push("all")
love.graphics.setCanvas(callerCanvas)
local callerDepth = #stack
local success = display.drawToCanvas(function()
    failNextPrint = true
    local ok = pcall(display.drawTinyText, 1, 8, "bad")
    assertEqual(ok, false, "script drawing error caught")
end)
assertEqual(success, true, "caught script error does not fail frame")
assertEqual(activeCanvas, callerCanvas, "caller canvas restored")
assertEqual(#stack, callerDepth, "leaked script push unwound")
love.graphics.pop()

-- Reproduce the reported script's uninitialised metadata table. The invalid
-- enum lookup remains a normal Lua error, never a graphics/present crash.
assert(display.drawToCanvas(function()
    local caught = pcall(function()
        local t = {}
        display.drawTinyText(150, 5, t.name)
        display.drawTinyText(150, 12, t.min)
        display.drawTinyText(150, 47, t.enumStrings[1])
    end)
    assertEqual(caught, false, "invalid metadata table raises a script error")
end))
assertEqual(activeCanvas, nil, "empty metadata cannot leave canvas active")
assertEqual(#stack, 0, "empty metadata cannot leak graphics state")

local ok, message = display.drawToCanvas(function()
    love.graphics.push("all")
    error("uncaught rendering failure")
end)
assertEqual(ok, false, "uncaught draw error returned")
assert(message:find("uncaught rendering failure", 1, true))
assertEqual(activeCanvas, nil, "canvas released after uncaught error")
assertEqual(#stack, 0, "stack restored after uncaught error")
assert(display.drawToCanvas(function() display.drawTinyText(1, 8, 123) end))
assertEqual(activeCanvas, nil, "subsequent frame can present")
assertEqual(#stack, 0, "subsequent frame stack balanced")

debug = originalDebug
print("text formatting tests passed")
