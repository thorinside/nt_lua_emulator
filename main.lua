-- main.lua
local emulator = require("modules.emulator")
local PathInputDialog = require("modules.path_input_dialog")
local debug_utils = require("modules.debug_utils")

-- Memory profiling configuration
local memoryProfilingEnabled = false
local memoryReportInterval = 10 -- seconds
local lastMemoryReport = 0
local gcMonitorInterval = 0.5 -- seconds
local lastGCMonitor = 0

function love.load()
    -- Initialize everything
    PathInputDialog.init()
    emulator.load()
    
    -- Enable memory profiling with F11 key
    print("Press F11 to toggle memory profiling")
end

function love.update(dt)
    PathInputDialog.update(dt)
    emulator.update(dt)
    
    -- Memory profiling if enabled
    if memoryProfilingEnabled then
        -- Monitor GC activity
        lastGCMonitor = lastGCMonitor + dt
        if lastGCMonitor >= gcMonitorInterval then
            debug_utils.monitorGC()
            lastGCMonitor = 0
        end
        
        -- Generate periodic memory reports
        lastMemoryReport = lastMemoryReport + dt
        if lastMemoryReport >= memoryReportInterval then
            debug_utils.takeMemorySnapshot("Periodic")
            lastMemoryReport = 0
            
            -- Print report every 5 intervals
            if math.floor(love.timer.getTime() / memoryReportInterval) % 5 == 0 then
                debug_utils.printMemoryReport()
            end
        end
    end
end

function love.draw()
    emulator.draw()
    PathInputDialog.draw()
    
    -- Display memory usage indicator when profiling is enabled
    if memoryProfilingEnabled then
        love.graphics.push("all")
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.print(string.format("Memory: %.2f KB", collectgarbage("count")), 10, 10)
        love.graphics.pop()
    end
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

    -- F11 to toggle memory profiling
    if key == "f11" then
        memoryProfilingEnabled = not memoryProfilingEnabled
        if memoryProfilingEnabled then
            emulator.enableMemoryProfiling()
            print("Memory profiling enabled")
        else
            emulator.disableMemoryProfiling()
            print("Memory profiling disabled")
        end
        return
    end

    -- F12 to toggle script-specific memory profiling
    if key == "f12" then
        local enabled = emulator.toggleScriptMemoryTracking()
        if enabled then
            print("Script memory profiling enabled")
            print("Now tracking memory usage of script functions:")
            print("  - step()")
            print("  - draw()")
            print("  - gate() (if present)")
            print("  - trigger() (if present)")
            print("Press F12 again to view memory usage report")
        end
        return
    end

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
