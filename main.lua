-- main.lua
local emulator = require("emulator")
local PathInputDialog = require("path_input_dialog")

function love.load()
    -- Initialize everything
    PathInputDialog.init()
    emulator.load()
end

function love.update(dt)
    PathInputDialog.update(dt)
    emulator.update(dt)
end

function love.draw()
    emulator.draw()
    PathInputDialog.draw()
end

function love.mousepressed(x, y, button)
    -- Handle mousepressed in path input dialog first if it's open
    if PathInputDialog.isOpen() then
        -- No mouse handling for path input right now
        return
    end

    emulator.mousepressed(x, y, button)
end

function love.mousemoved(x, y, dx, dy) emulator.mousemoved(x, y, dx, dy) end
function love.mousereleased(x, y, button) emulator.mousereleased(x, y, button) end
function love.wheelmoved(x, y)
    -- Handle wheelmoved in path input dialog first if it's open
    if PathInputDialog.isOpen() then
        if PathInputDialog.wheelmoved(x, y) then return end
    end

    emulator.wheelmoved(x, y)
end

function love.keypressed(key, scancode, isrepeat)
    -- Alt+F4 or Command+Q to quit
    if (key == "f4" and love.keyboard.isDown("lalt")) or
        (key == "q" and love.keyboard.isDown("lgui")) then love.event.quit() end

    -- Check for F2 key to open path input dialog
    if key == "f2" and not PathInputDialog.isOpen() then
        PathInputDialog.open(function(filePath)
            emulator.loadScriptFromPath(filePath)
        end)
        return
    end

    -- Handle keypressed in path input dialog first if it's open
    if PathInputDialog.isOpen() then
        if PathInputDialog.keypressed(key, scancode, isrepeat) then
            return
        end
    end

    -- Pass keypressed events to emulator
    emulator.keypressed(key, isrepeat)
end

function love.keyreleased(key)
    -- Handle key releases in path input dialog first if it's open
    if PathInputDialog.isOpen() then
        if PathInputDialog.keyreleased(key) then return end
    end

    -- Pass keyreleased events to emulator if needed
    if emulator.keyreleased then emulator.keyreleased(key) end
end

function love.textinput(text)
    -- Handle text input in path input dialog if it's open
    if PathInputDialog.isOpen() then
        if PathInputDialog.textinput(text) then return end
    end
end

-- Add a quit callback to save state when the app closes
function love.quit()
    print("Application is closing, saving state...")

    -- Call emulator's quit function to save state and clean up
    if emulator and emulator.quit then emulator.quit() end

    -- Return false to allow the application to close (return true would cancel closing)
    return false
end
