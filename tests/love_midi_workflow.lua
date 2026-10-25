-- Installed as main.lua by run_love_midi_workflow.sh in a disposable checkout.
-- These tests call actual love.key*/mouse* entry points, not script callbacks.
local traceback = debug.traceback
local fakeNative = os.getenv("MIDI_WORKFLOW_NATIVE") == "fake"
local pending, sent = {}, {}
if fakeNative then
    package.preload.luamidi = function() return {
        getinportcount = function() return 1 end, getoutportcount = function() return 1 end,
        getInPortName = function() return "Test input" end,
        getOutPortName = function() return "Test output (no hardware)" end,
        openin = function() return true end, openout = function() return true end,
        closein = function() end, closeout = function() end,
        getMessage = function()
            local message = table.remove(pending, 1)
            if message then return message[1], message[2], message[3] end
        end,
        sendMessage = function(_, ...) sent[#sent + 1] = {...} end
    } end
else
    package.preload.luamidi = function() error("Native MIDI intentionally unavailable") end
    package.preload.midi = function() error("Native MIDI intentionally unavailable") end
end
require("app")
local appLoad, appUpdate, appDraw = love.load, love.update, love.draw
local emulator = require("modules.emulator")
local monitor = require("modules.midi_monitor")
local chooser = require("modules.midi_output_dialog")
local controls = require("modules.controls")
local handler = emulator.getMidiHandler()
local notifications = require("modules.notifications")
local originalError, originalPrint = notifications.showErrorNotification, love.graphics.print
local errors, rendered, frames, echoCount = 0, {}, 0, 0
notifications.showErrorNotification = function(message)
    errors = errors + 1; print("UNEXPECTED SCRIPT ERROR", message); originalError(message)
end
love.graphics.print = function(value, ...)
    rendered[#rendered + 1] = tostring(value)
    return originalPrint(value, ...)
end
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function history() return handler.getOutputHistory() end
local function last() local events = history(); return events[#events] end
local function key(keyName) love.keypressed(keyName); love.keyreleased(keyName) end
local function click(px, py) love.mousepressed(px, py, 1); love.mousereleased(px, py, 1) end
local function header(offset)
    local bounds = monitor.getBounds(); click(bounds.x + bounds.width - offset, bounds.y + 12)
end
local function internalCount() return handler.getDestinationRoutes()[4].count end
local steps = {
    [3] = function()
        key("f4"); assert(chooser.isActive())
        key("return"); equal(handler.getDestinationRoutes()[1].forward, true)
        key("return"); equal(handler.getDestinationRoutes()[1].forward, false)
        key("a") -- Used to be suppressed by the F4 modal guard.
        equal(#history(), 2, "F4 keyboard note on/off")
        equal(history()[1].bytes[1], 0x90); equal(last().bytes[1], 0x80)
        equal(last().delivery, "monitor")
    end,
    [4] = function()
        for i = 1, 4 do key("down") end
        key("return") -- Actual chooser entry opens the live log.
        assert(not chooser.isActive()); assert(monitor.isVisible())
        click(controls[7].x, controls[7].y)
        equal(#history(), 4, "mouse button note on/off with monitor open")
    end,
    [5] = function()
        love.mouse.setPosition(controls[1].x, controls[1].y); love.wheelmoved(0, 1)
        equal(last().destinations, 2, "pot-wheel callback reaches capture")
        equal(last().bytes[1], 0xB0)
        love.mouse.setPosition(controls[4].x, controls[4].y); love.wheelmoved(0, 1)
        equal(last().destinations, 1, "encoder-wheel callback reaches capture")
        key("q") -- Continuous step-generated CC output.
    end,
    [10] = function() header(160); assert(monitor.isPaused()) end,
    [14] = function() header(160); assert(not monitor.isPaused()) end,
    [16] = function()
        key("q")
        assert(require("modules.script_manager").getScript().stepMessages > 0)
    end,
    [17] = function()
        key("f") -- Deliberate mask 0 / invalid-mask calls must be visible.
        equal(history()[#history() - 1].delivery, "ignored")
        equal(last().delivery, "invalid")
        local bounds = monitor.getBounds()
        love.mouse.setPosition(bounds.x + 30, bounds.y + 80) -- Hover full rejection reason.
    end,
    [19] = function() header(85); equal(#history(), 0); equal(internalCount(), 0) end,
    [20] = function()
        key("f5"); assert(not monitor.isVisible())
        key("f5"); assert(monitor.isVisible())
        love.keypressed("a") -- Hold a note, open routing, then release it.
        key("f4"); love.keyreleased("a")
        equal(#history(), 2); equal(last().bytes[1], 0x80)
    end,
    [21] = function() key("f5"); assert(not chooser.isActive()); assert(monitor.isVisible()) end,
    [22] = function()
        assert(emulator.loadScriptFromPath("tests/fixtures/midi_workflow.lua"))
        key("a"); equal(#history(), 4, "capture survives script reload")
        if fakeNative then assert(handler.openInputPort(0)); echoCount = internalCount() end
    end,
    [23] = function() if fakeNative then pending[1] = {0x90, 61, 90} end end,
    [24] = function() if fakeNative then equal(internalCount(), echoCount + 1); pending[1] = {0xB0, 7, 90} end end,
    [25] = function() if fakeNative then equal(internalCount(), echoCount + 2); pending[1] = {0xE0, 0, 64} end end,
    [26] = function() if fakeNative then equal(internalCount(), echoCount + 3); pending[1] = {0xD0, 80} end end,
    [27] = function() if fakeNative then equal(internalCount(), echoCount + 4); pending[1] = {0xA0, 61, 80} end end,
    [28] = function() if fakeNative then equal(internalCount(), echoCount + 5); pending[1] = {0xC0, 3} end end,
    [29] = function()
        if fakeNative then
            equal(internalCount(), echoCount + 6, "all six documented MIDI input filters")
            setParameter(1, 2, 0); pending[1] = {0x90, 61, 90}
        end
    end,
    [30] = function()
        if fakeNative then
            equal(internalCount(), echoCount + 6, "channel 0 disables input")
            setParameter(1, 2, 1); pending[1] = {0x91, 61, 90}
        end
    end,
    [31] = function() if fakeNative then equal(internalCount(), echoCount + 6, "other channel ignored") end end,
    [33] = function()
        handler.setDestinationRoute(4, true)
        if fakeNative then assert(handler.openOutputPort(0)) end
        key("a")
        equal(last().delivery, fakeNative and "sent" or "unavailable")
        if fakeNative then
            equal(#sent, 2)
            -- Combined logical transports share one physical output, not 3 copies.
            sendMIDI(7, 0xF8); equal(#sent, 3)
            handler.closeOutputPort(); key("a"); equal(last().delivery, "unavailable")
        end
    end,
    [37] = function()
        local before = monitor.getBounds()
        love.mousepressed(before.x + 12, before.y + 12, 1)
        love.mousemoved(before.x + 12, before.y - 18, 0, -30)
        love.mousereleased(before.x + 12, before.y - 18, 1)
        equal(monitor.getBounds().y, before.y - 30, "drag log through actual mouse handlers")
    end,
    [38] = function()
        local bounds = monitor.getBounds()
        love.mouse.setPosition(bounds.x + 30, bounds.y + 100)
        love.wheelmoved(0, 1)
        assert(monitor.isPaused(), "scroll pauses only the view")
    end,
    [39] = function() header(160); assert(not monitor.isPaused()) end,
    [42] = function()
        equal(errors, 0, "no script/renderer errors")
        print("LOVE_MIDI_WORKFLOW_PASSED", fakeNative and "fake-native" or "no-native")
        love.event.quit()
    end
}
function love.load(...)
    appLoad(...)
    assert(emulator.loadScriptFromPath("tests/fixtures/midi_workflow.lua"))
    equal(handler.isAvailable(), fakeNative)
    handler.clearOutputHistory()
    for _, route in ipairs(handler.getDestinationRoutes()) do equal(route.forward, false) end
end
function love.update()
    frames = frames + 1
    if steps[frames] then steps[frames]() end
    appUpdate(0.025)
end
function love.draw()
    rendered = {}; appDraw()
    local text = table.concat(rendered, "\n")
    if frames == 9 then assert(text:find("CC ch1", 1, true), text) end
    if frames == 12 then assert(text:find("View paused; script and capture still running", 1, true), text) end
    if frames == 18 then
        assert(text:find("Ignored (mask 0)", 1, true), text)
        assert(text:find("Destination mask must be an integer", 1, true), text)
    end
    if frames == 19 then assert(text:find("Waiting for sendMIDI() calls", 1, true), text) end
    assert(love.graphics.getCanvas() == nil); equal(love.graphics.getStackDepth(), 0)
    local screenshots = {[18] = "diagnostics", [19] = "empty", [40] = "workflow"}
    if screenshots[frames] then
        local filename = "midi-" .. screenshots[frames] .. ".png"
        love.graphics.captureScreenshot(function(data)
            local file = assert(io.open(filename, "wb"))
            file:write(data:encode("png"):getString()); file:close()
        end)
    end
end
function love.errorhandler(message)
    print(traceback(message)); love.graphics.setCanvas()
    return function() love.event.quit(1) end
end
