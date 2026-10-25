-- Installed as main.lua in a disposable copy by run_love_hardening.sh.
io.stdout:setvbuf("no")
local traceback = debug.traceback
package.preload.luamidi = function() error("Native MIDI intentionally unavailable") end
package.preload.midi = function() error("Native MIDI intentionally unavailable") end
require("app")
local appLoad, appUpdate, appDraw = love.load, love.update, love.draw
local frames = 0
function love.load(...)
    appLoad(...)
    assert(require("modules.script_manager").getScript(), "default script must survive bad saved files")
    love.keypressed("f2")
end
function love.update(dt)
    frames = frames + 1
    appUpdate(dt)
    if frames == 5 then love.keypressed("escape") end
    if frames == 10 then print("LOVE_HARDENING_PASSED"); love.event.quit(0) end
end
function love.draw()
    appDraw()
    assert(love.graphics.getCanvas() == nil)
    assert(love.graphics.getStackDepth() == 0)
end
function love.errorhandler(message)
    print(traceback(message))
    return function() return 1 end
end
