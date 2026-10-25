local sent = {}
local router = require("modules.midi_router").create(function(...)
    sent[#sent + 1] = {...}
    return true
end)
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
router.send(1, 0x90, 60, 100)
equal(#sent, 1)
router.send(7, 0x90, 60, 100)
equal(#sent, 2) -- Combined destinations must not duplicate on the same port.
router.send(8, 0x80, 60, 0)
equal(#sent, 2) -- Internal defaults to monitor only, no feedback loop.
equal(router.getRoutes()[1].count, 2)
equal(router.getRoutes()[4].count, 1)
equal(router.getHistory()[3].destinations, 8)
equal(router.getHistory()[3].forwarded, false)
router.setRoute(8, true)
router.send(8, 0xF8)
equal(#sent, 3)
equal(sent[3][1], 0xF8)
router.setRoute(1, false)
router.send(1, 0x90, 60, 100)
equal(#sent, 3)
equal(router.send(0, 0xF8), true)
equal(#router.getHistory(), 6)
equal(router.getHistory()[6].delivery, "ignored")
assert(router.getHistory()[6].reason:find("mask 0", 1, true))
equal(router.send(16, 0xF8), false)
equal(router.send(1, 256), false)
equal(router.send(1, 0x90, 60, 1, 2), false)
equal(router.getHistory()[7].delivery, "invalid")
equal(router.getHistory()[8].delivery, "invalid")
equal(router.getHistory()[9].delivery, "invalid")
equal(router.setRoute(16, true), false)
local history = router.getHistory()
history[1].bytes[1] = 0
local routes = router.getRoutes()
routes[1].last[1] = 0
equal(router.getHistory()[1].bytes[1], 0x90)
equal(router.getRoutes()[1].last[1], 0x90)
local _, beforeSequence = router.getHistoryState()
for i = 1, 200 do router.send(8, 0xF8) end
history = router.getHistory()
equal(#history, 128)
equal(history[1].id, beforeSequence + 73)
equal(history[128].id, beforeSequence + 200)
local recent = router.getHistory(3)
equal(#recent, 3)
equal(recent[1].id, beforeSequence + 198)
equal(recent[3].id, history[128].id)
equal(#router.getHistory(0), 0)
equal(#router.getHistory(500), 128)
recent[3].bytes[1] = 0
equal(router.getHistory(1)[1].bytes[1], 0xF8)

-- Firmware API routes and records messages even when native MIDI is absent.
local handler = {
    isAvailable = function() return false end,
    sendToDestinations = router.send,
    getDestinationRoutes = router.getRoutes,
    setDestinationRoute = router.setRoute,
    getCurrentOutputPortIndex = function() return -1 end
}
local api = require("modules.nt_api").create({
    display = {createDrawingEnvironment = function() return {} end},
    helpers = require("modules.helpers"),
    getMidiHandler = function() return handler end
})
api.sendMIDI(8, 0x90, 64, 127)
equal(router.getRoutes()[4].last[2], 64)
api.sendMIDI(-1, 0xF8)
equal(router.getRoutes()[4].last[2], 64)
local rejected = router.getHistory()
equal(rejected[#rejected].delivery, "invalid")
api.sendMIDI(1, nil, 64)
rejected = router.getHistory()
equal(rejected[#rejected].delivery, "invalid")
local beforeClear = router.getHistoryState()
router.clear()
local afterClear, clearedSequence = router.getHistoryState()
assert(afterClear > beforeClear, "clear must invalidate snapshots even when IDs restart")
equal(clearedSequence, 0)
equal(#router.getHistory(), 0)
equal(router.getRoutes()[1].count, 0)
equal(router.getRoutes()[1].last, nil)
api.sendMIDI(8, 0x90, 64, 127)

-- Chooser still exposes route controls and live byte monitors without hardware.
local printed = {}
_G.love = {graphics = {
    getWidth = function() return 800 end,
    getHeight = function() return 600 end,
    setColor = function() end,
    rectangle = function() end,
    setFont = function() end,
    newFont = function() return {} end,
    getFont = function() return {getWidth = function() return 100 end} end,
    print = function(value) printed[#printed + 1] = value end,
    setScissor = function() end
}}
local dialog = require("modules.midi_output_dialog")
local openedLog = false
dialog.init({midiHandler = handler, onShowMonitor = function() openedLog = true end})
assert(dialog.show())
equal(dialog.getSelectedPort().destination, 1)
local before = router.getRoutes()[1].forward
dialog.keypressed("return")
equal(router.getRoutes()[1].forward, not before)
equal(dialog.isActive(), true)
dialog.draw()
assert(table.concat(printed, "\n"):find("90 40 7F", 1, true))
-- Six rows produce a centered 260px dialog; first row starts at y=230.
dialog.mousepressed(250, 250, 1)
equal(router.getRoutes()[1].forward, before)
dialog.keypressed("escape")
equal(dialog.isActive(), false)
dialog.show()
for i = 1, 4 do dialog.keypressed("down") end
equal(dialog.getSelectedPort().monitor, true)
dialog.keypressed("return")
equal(openedLog, true)
equal(dialog.isActive(), false)

-- Native handler also exposes a monitor before any native MIDI initialization.
local native = require("modules.midi_handler")
native.sendToDestinations(8, 0xF8)
equal(native.getOutputHistory()[1].bytes[1], 0xF8)
equal(native.getOutputHistory()[1].forwarded, false)
-- Selecting an input cannot disconnect the independently chosen host output.
local closedOutputs = 0
package.loaded.luamidi = {
    getinportcount = function() return 1 end,
    getoutportcount = function() return 1 end,
    openin = function() return true end,
    openout = function() return true end,
    closein = function() end,
    closeout = function() closedOutputs = closedOutputs + 1 end
}
package.loaded["modules.midi_handler"] = nil
local connected = require("modules.midi_handler")
assert(connected.init())
assert(connected.openOutputPort(0))
assert(connected.openInputPort(0))
equal(connected.getCurrentOutputPortIndex(), 0)
equal(closedOutputs, 0)
connected.close()
equal(closedOutputs, 1)

-- Configuration retains selected output and false (monitor-only) route flags.
-- Redirect only config.json to a temporary file; never touch the user's config.
local config = require("modules.config")
local temporary = os.tmpname()
local originalOpen = io.open
io.open = function(path, mode)
    return originalOpen(path == "config.json" and temporary or path, mode)
end
assert(config.save({midi = {enabled = true, selectedInput = -1, selectedOutput = 2,
                          destinationRoutes = {["1"] = false, ["8"] = true}}}))
local saved = config.load()
io.open = originalOpen
os.remove(temporary)
equal(saved.midi.selectedOutput, 2)
equal(saved.midi.destinationRoutes["1"], false)
equal(saved.midi.destinationRoutes["8"], true)
print("MIDI routing tests passed")
