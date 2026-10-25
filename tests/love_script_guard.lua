-- Disposable-workspace integration test; run_love_hardening.sh supplies timeout.
io.stdout:setvbuf("no")
local traceback, gethook = debug.traceback, debug.gethook
package.preload.luamidi = function() error("Native MIDI intentionally unavailable") end
package.preload.midi = function() error("Native MIDI intentionally unavailable") end
require("app")
local emulator = require("modules.emulator")
local manager = require("modules.script_manager")
local loader = require("modules.script_loader")
local guard = require("modules.script_guard")
local display = require("modules.display")
local appLoad, appUpdate, appDraw = love.load, love.update, love.draw
local function write(name, content)
    local f = assert(io.open(name, "w")); assert(f:write(content)); assert(f:close())
end
local function stateBytes()
    local f = assert(io.open("state.json", "r")); local content = f:read("*a"); f:close(); return content
end
local failures = {
    chunk = "while true do end",
    init = "return {init=function() while true do end end}",
    setup = "return {setupUi=function() while true do end end}",
    ordinary = "return {init=function() error('broken init') end}",
    scalar = "return 42",
    infiniteIO = "return {init=function() return {inputs=math.huge} end}",
    negativeIO = "return {outputs=-1}",
    fractionalIO = "return {inputs=1.5}",
    syntax = "return { this is not Lua",
}
function love.load(...)
    appLoad(...)
    local oldScript, oldPath = manager.getScript(), manager.getScriptPath()
    local oldGlobals, oldPackagePath, saved = getParameter, package.path, stateBytes()
    assert(oldScript)
    for name, source in pairs(failures) do
        local filename = "guard-" .. name .. ".lua"
        write(filename, source)
        local path = name == "init" and love.filesystem.getWorkingDirectory() .. "/" .. filename or filename
        assert(not emulator.loadScriptFromPath(path), name .. " must fail")
        assert(manager.getScript() == oldScript and manager.getScriptPath() == oldPath)
        assert(getParameter == oldGlobals and package.path == oldPackagePath, "failed load must restore SDK bindings")
        assert(stateBytes() == saved, "failed load must not persist the new path")
        assert(not guard.isDisabled(oldScript.draw), "old script remains usable")
    end
    -- Retrying the same path must clear require's previous-error sentinel.
    write("guard-chunk.lua", "return {init=function() end, draw=function() return true end}")
    assert(emulator.loadScriptFromPath("guard-chunk.lua"))
    write("guard-callbacks.lua", [[return {
        init = function() return {inputs={},outputs={}} end,
        step = function() while true do end end,
        draw = function() love.graphics.push('all'); while true do end end,
        button1Push = function() while true do end end,
        serialise = function() while true do end end
    }]])
    assert(emulator.loadScriptFromPath("guard-callbacks.lua"))
    local script = manager.getScript()
    appUpdate(0.001) -- Activate real hardware controls before keyboard events.
    manager.callScriptStep(0.001, {})
    assert(guard.isDisabled(script.step))
    manager.callScriptStep(0.001, {}) -- Must skip, not time out a second time.
    local depth, canvas = love.graphics.getStackDepth(), love.graphics.getCanvas()
    assert(display.drawToCanvas(function() manager.callScriptDraw() end))
    assert(guard.isDisabled(script.draw))
    assert(love.graphics.getStackDepth() == depth and love.graphics.getCanvas() == canvas)
    love.keypressed("q"); love.keyreleased("q")
    assert(guard.isDisabled(script.button1Push))
    assert(loader.serialiseState(script) == nil and guard.isDisabled(script.serialise))
    assert(loader.serialiseState(script) == nil)
    -- UI callbacks have no injected self, and need the watchdog too.
    write("guard-ui.lua", "return {init=function() return true end, button1Push=function() while true do end end}")
    assert(emulator.loadScriptFromPath("guard-ui.lua"))
    love.keypressed("q"); love.keyreleased("q")
    assert(guard.isDisabled(manager.getScript().button1Push))
    write("guard-extensionless", "return {init=function() end}")
    assert(emulator.loadScriptFromPath(love.filesystem.getWorkingDirectory() .. "/guard-extensionless"))
    assert(emulator.loadScriptFromPath("test_script.lua"), "healthy script must load after all failures")
    assert(gethook() == nil, "watchdog must restore hooks")
end
local frames = 0
function love.update(dt)
    appUpdate(dt)
    frames = frames + 1
    if frames == 10 then print("LOVE_HARDENING_PASSED"); love.event.quit(0) end
end
function love.draw()
    appDraw()
    assert(love.graphics.getCanvas() == nil and love.graphics.getStackDepth() == 0)
end
function love.errorhandler(message)
    print(traceback(message))
    return function() return 1 end
end
