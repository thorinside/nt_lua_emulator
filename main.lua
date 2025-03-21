-- main.lua
local emulator = require("emulator")

function love.load() emulator.load() end
function love.update(dt) emulator.update(dt) end
function love.draw() emulator.draw() end
function love.mousepressed(x, y, button) emulator.mousepressed(x, y, button) end
function love.mousemoved(x, y, dx, dy) emulator.mousemoved(x, y, dx, dy) end
function love.mousereleased(x, y, button) emulator.mousereleased(x, y, button) end
function love.wheelmoved(x, y) emulator.wheelmoved(x, y) end
function love.keypressed(key)
    -- Alt+F4 or Command+Q to quit
    if (key == "f4" and love.keyboard.isDown("lalt")) or
        (key == "q" and love.keyboard.isDown("lgui")) then love.event.quit() end

    -- Pass keypressed events to emulator
    emulator.keypressed(key)
end
