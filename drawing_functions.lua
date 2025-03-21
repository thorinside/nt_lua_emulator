-- drawing_functions.lua
-- Defines the global drawing functions (drawText, drawBox, etc.)
-- with correct handling of optional parameters as per the Disting NT manual.
function drawText(x, y, text, col)
    local tinyFont = love.graphics.newFont(8)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(tinyFont)
    local c = col or 15
    love.graphics.setColor(c / 15, c / 15, c / 15)
    love.graphics.print(text, x, y)
    love.graphics.setFont(prevFont)
end

function drawBox(x1, y1, x2, y2, col)
    local c = col or 15
    love.graphics.setColor(c / 15, c / 15, c / 15)
    love.graphics.rectangle("line", math.floor(x1), math.floor(y1),
                            math.floor(x2 - x1), math.floor(y2 - y1))
end

function drawLine(x1, y1, x2, y2, col)
    local c = col or 15
    love.graphics.setColor(c / 15, c / 15, c / 15)
    love.graphics.line(math.floor(x1), math.floor(y1), math.floor(x2),
                       math.floor(y2))
end

function drawParameterLine(algIndex, paramIndex, yOffset)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Alg " .. algIndex .. " Param " .. paramIndex, 10,
                        yOffset)
end

function drawRectangle(x1, y1, x2, y2, col)
    local c = col or 15
    love.graphics.setColor(c / 15, c / 15, c / 15)
    love.graphics.rectangle("fill", math.floor(x1), math.floor(y1),
                            math.floor(x2 - x1), math.floor(y2 - y1))
end

function drawSmoothLine(x1, y1, x2, y2, col)
    local c = col or 15
    love.graphics.setColor(c / 15, c / 15, c / 15)
    love.graphics.line(x1, y1, x2, y2)
end

function drawStandardParameterLine()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Standard Parameter Line", 10, 10)
end

function drawTinyText(x, y, text)
    local tinyFont = love.graphics.newFont(6)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(tinyFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x, y)
    love.graphics.setFont(prevFont)
end

function drawAlgorithmUI(looper)
    -- Typically draws the script's custom GUI
    if script and script.draw then script.draw(script) end
end

function exit() love.event.quit() end
