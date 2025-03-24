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
    brightnessExp = 0.65, -- Exponent for brightness curve (< 1 makes dim colors brighter)
    pixelFont = nil, -- Will hold the PixelmixRegular font
    tinyFont = nil -- Will hold the tom-thumb font
}

-- Shared color calculation function with non-linear brightness adjustment
local function calculateColor(colorValue)
    -- Ensure we have a valid color value
    if colorValue == nil then colorValue = 15 end

    -- Base brightness adjustment with better handling for dark colors
    local shade = math.max(colorValue, 0) / 15

    -- For dark colors, use a more gentle curve to preserve distinction
    if colorValue <= 2 then
        -- Use lighter exponent for very dark colors to keep them visible
        -- but still distinguishable from each other
        shade = math.pow(shade, 0.45)
    else
        -- Normal brightness curve for regular colors
        shade = math.pow(shade, config.brightnessExp)
    end

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
    love.graphics.setDefaultFilter("linear", "linear", 8)

    -- Load the fonts
    -- Regular font for drawText
    config.pixelFont = love.graphics.newFont("fonts/PixelmixRegular-z07w.ttf",
                                             8 * config.scaling)

    -- font for drawTinyText (using BMFontRasterizer)
    config.tinyFont = love.graphics.newFont("fonts/tom-thumb.ttf",
                                            5 * config.scaling)

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

-- Draw a rectangle (filled)
function display.drawRectangle(x1, y1, x2, y2, color)
    local col = calculateColor(color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.rectangle("fill", x1 * config.scaling, y1 * config.scaling,
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

    -- Save current font
    local currentFont = love.graphics.getFont()

    -- Use our pixel font
    love.graphics.setFont(config.pixelFont)

    -- Draw the text
    love.graphics.print(text, x * config.scaling, y * config.scaling)

    -- Restore the previous font
    love.graphics.setFont(currentFont)
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
    -- Save current color so we can restore it
    local r, g, b, a = love.graphics.getColor()

    -- Draw to canvas
    love.graphics.setCanvas(config.canvas)
    -- We don't clear here, as that should be handled by the user
    love.graphics.setCanvas() -- Reset to default canvas

    -- Draw the canvas to the screen
    love.graphics.setColor(1, 1, 1, 1) -- Always set to white for the canvas drawing
    love.graphics.draw(config.canvas, 0, 0)

    -- Restore previous color
    love.graphics.setColor(r, g, b, a)
end

-- Update the display (does nothing, but provided for API completeness)
function display.update(dt)
    -- Nothing to do here, but can be used for animations or other timed effects
end

-- Get the current configuration
function display.getConfig() return config end

-- Draw text with tiny font (using tom-thumb.bdf)
function display.drawTinyText(x, y, text, color)
    local col = calculateColor(color or 15)
    love.graphics.setColor(col[1], col[2], col[3])

    -- Save current font
    local currentFont = love.graphics.getFont()

    -- Use our tiny font
    love.graphics.setFont(config.tinyFont)

    -- Draw the text
    love.graphics.print(text, x * config.scaling, y * config.scaling)

    -- Restore the previous font
    love.graphics.setFont(currentFont)
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
        fillCircle = display.fillCircle
    }
end

return display
