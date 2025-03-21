-- display.lua - Simulated display library for LÖVE 15.1
-- Provides drawing functions for emulating a small OLED/LCD display
local display = {
    _VERSION = "1.0.0",
    _DESCRIPTION = "Display simulator for hardware modules"
}

-- Default configuration
local config = {
    width = 256,
    height = 64,
    scaling = 4,
    baseColor = {0, 1, 1}, -- Electric blue tint (R, G, B)
    canvas = nil,
    brightnessExp = 0.85 -- Exponent for brightness curve (< 1 makes dim colors brighter)
}

-- Shared color calculation function with non-linear brightness adjustment
local function calculateColor(colorValue)
    local shade = math.max(colorValue, 5) / 15 -- Base brightness adjustment
    shade = math.pow(shade, config.brightnessExp) -- Non-linear brightness curve
    return {
        shade * config.baseColor[1], shade * config.baseColor[2],
        shade * config.baseColor[3]
    }
end

-- Initialize the display
function display.init(options)
    -- Override defaults with provided options
    if options then for k, v in pairs(options) do config[k] = v end end

    -- Create the canvas
    config.canvas = love.graphics.newCanvas(config.width * config.scaling,
                                            config.height * config.scaling)

    -- Configure default filters
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Configure window if we're managing it
    if options and options.manageWindow then
        love.window.setMode(config.width * config.scaling,
                            config.height * config.scaling)
        love.graphics.setBackgroundColor(0, 0, 0)
    end

    return display
end

-- Clear the display
function display.clear() love.graphics.clear(0, 0, 0, 1) end

-- Draw a rectangle (outlined)
function display.drawRectangle(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.rectangle("line", x1 * config.scaling, y1 * config.scaling,
                            (x2 - x1) * config.scaling,
                            (y2 - y1) * config.scaling)
end

-- Draw a smooth box (outlined)
function display.drawSmoothBox(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.rectangle("line", x1 * config.scaling, y1 * config.scaling,
                            (x2 - x1) * config.scaling,
                            (y2 - y1) * config.scaling)
end

-- Draw a box with minimum brightness (outlined)
function display.drawBox(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.rectangle("line", x1 * config.scaling, y1 * config.scaling,
                            (x2 - x1) * config.scaling,
                            (y2 - y1) * config.scaling)
end

-- Draw a smooth line
function display.drawSmoothLine(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.line(x1 * config.scaling, y1 * config.scaling,
                       x2 * config.scaling, y2 * config.scaling)
end

-- Draw a line (handles single point cases as particles)
function display.drawLine(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])

    if math.floor(x1) == math.floor(x2) and math.floor(y1) == math.floor(y2) then
        -- Single point (particle) case
        love.graphics.points(x1 * config.scaling, y1 * config.scaling)
    else
        -- Standard line case
        love.graphics.line(x1 * config.scaling, y1 * config.scaling,
                           x2 * config.scaling, y2 * config.scaling)
    end
end

-- Draw text
function display.drawText(x, y, text, color)
    local col = calculateColor(color or 15)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.print(text, x * config.scaling, y * config.scaling)
end

-- Fill a rectangle
function display.fillRectangle(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.rectangle("fill", x1 * config.scaling, y1 * config.scaling,
                            (x2 - x1) * config.scaling,
                            (y2 - y1) * config.scaling)
end

-- Draw a filled circle
function display.fillCircle(x, y, radius, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.circle("fill", x * config.scaling, y * config.scaling,
                         radius * config.scaling)
end

-- Draw an outlined circle
function display.drawCircle(x, y, radius, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.circle("line", x * config.scaling, y * config.scaling,
                         radius * config.scaling)
end

-- Set the base color for all drawing
function display.setBaseColor(r, g, b)
    if type(r) == "table" then
        config.baseColor = {r[1], r[2], r[3]}
    else
        config.baseColor = {r, g, b}
    end
end

-- Render the display to the screen
function display.render()
    -- Draw to canvas
    love.graphics.setCanvas(config.canvas)
    -- We don't clear here, as that should be handled by the user
    love.graphics.setCanvas() -- Reset to default canvas

    -- Draw the canvas to the screen
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(config.canvas, 0, 0)
end

-- Update the display (does nothing, but provided for API completeness)
function display.update(dt)
    -- Nothing to do here, but can be used for animations or other timed effects
end

-- Get the current configuration
function display.getConfig() return config end

-- Draw text with tiny 3x5 pixel font
function display.drawTinyText(x, y, text, color)
    local col = calculateColor(color)

    -- Implementation of tiny 3x5 pixel font
    love.graphics.push()
    love.graphics.setColor(col[1], col[2], col[3]) -- White text

    -- Use a low-resolution scale for tiny text
    local scale = 1
    local charWidth = 4 * scale -- 3 pixels + 1 pixel spacing
    local charHeight = 5 * scale

    -- Define the tiny font as pixel patterns (1=pixel on, 0=pixel off)
    local tinyFont = {
        [" "] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        ["!"] = {0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0},
        ['"'] = {1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        ["#"] = {1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1},
        ["$"] = {0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0},
        ["%"] = {1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1},
        ["&"] = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1},
        ["'"] = {0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        ["("] = {0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1},
        [")"] = {1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0},
        ["*"] = {0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0},
        ["+"] = {0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0},
        [","] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0},
        ["-"] = {0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0},
        ["."] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0},
        ["/"] = {0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0},
        ["0"] = {0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0},
        ["1"] = {0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1},
        ["2"] = {1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1},
        ["3"] = {1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0},
        ["4"] = {1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1},
        ["5"] = {1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0},
        ["6"] = {0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0},
        ["7"] = {1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0},
        ["8"] = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0},
        ["9"] = {0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0},
        [":"] = {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0},
        [";"] = {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0},
        ["<"] = {0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
        ["="] = {0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0},
        [">"] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0},
        ["?"] = {0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0},
        ["@"] = {0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1},
        ["A"] = {0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1},
        ["B"] = {1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0},
        ["C"] = {0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1},
        ["D"] = {1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0},
        ["E"] = {1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1},
        ["F"] = {1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0},
        ["G"] = {0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1},
        ["H"] = {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1},
        ["I"] = {1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1},
        ["J"] = {0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0},
        ["K"] = {1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1},
        ["L"] = {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1},
        ["M"] = {1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1},
        ["N"] = {1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1},
        ["O"] = {0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0},
        ["P"] = {1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0},
        ["Q"] = {0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1},
        ["R"] = {1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1},
        ["S"] = {0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0},
        ["T"] = {1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0},
        ["U"] = {1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0},
        ["V"] = {1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0},
        ["W"] = {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1},
        ["X"] = {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1},
        ["Y"] = {1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0},
        ["Z"] = {1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1},
        ["["] = {1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0},
        ["\\"] = {1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1},
        ["]"] = {0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1},
        ["^"] = {0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        ["_"] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1},
        ["`"] = {1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        ["a"] = {0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1},
        ["b"] = {1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0},
        ["c"] = {0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1},
        ["d"] = {0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1},
        ["e"] = {0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1},
        ["f"] = {0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0},
        ["g"] = {0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0},
        ["h"] = {1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1},
        ["i"] = {0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1},
        ["j"] = {0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0},
        ["k"] = {1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1},
        ["l"] = {1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1},
        ["m"] = {0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1},
        ["n"] = {0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1},
        ["o"] = {0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0},
        ["p"] = {0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0},
        ["q"] = {0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1},
        ["r"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0},
        ["s"] = {0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0},
        ["t"] = {0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1},
        ["u"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1},
        ["v"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0},
        ["w"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0},
        ["x"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
        ["y"] = {0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0},
        ["z"] = {0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1},
        ["{"] = {0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1},
        ["|"] = {0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0},
        ["}"] = {1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0},
        ["~"] = {0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0}
    }

    -- Draw each character in the string
    for i = 1, #text do
        local char = text:sub(i, i)
        local pattern = tinyFont[char] or tinyFont["?"] -- Default to "?" for unknown characters

        -- Draw the character pixel by pixel
        for row = 0, 4 do
            for col = 0, 2 do
                local pixelIndex = row * 3 + col + 1
                if pattern[pixelIndex] == 1 then
                    love.graphics.rectangle("fill", x + (i - 1) * charWidth +
                                                col * scale,
                                            y - (4 * scale) + row * scale,
                                            scale, scale)
                end
            end
        end
    end

    love.graphics.pop()
end

-- Create an environment with drawing functions for script sandboxing
function display.createDrawingEnvironment()
    return {
        drawRectangle = display.drawRectangle,
        drawSmoothBox = display.drawSmoothBox,
        drawBox = display.drawBox,
        drawSmoothLine = display.drawSmoothLine,
        drawLine = display.drawLine,
        drawText = display.drawText,
        drawTinyText = display.drawTinyText,
        fillRectangle = display.fillRectangle,
        drawCircle = display.drawCircle,
        fillCircle = display.fillCircle,
        -- Constants that might be used by scripts
        kBy10 = 10,
        kVolts = 1
    }
end

return display
