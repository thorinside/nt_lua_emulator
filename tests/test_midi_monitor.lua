local printed, positions = {}, {}
local pointerX, pointerY = 0, 0
love = {graphics = {
    getWidth = function() return 800 end, getHeight = function() return 600 end,
    newFont = function() return {getWidth = function(_, text) return #text * 6 end} end, setFont = function() end,
    push = function() end, pop = function() end,
    setColor = function() end, rectangle = function() end, setScissor = function() end,
    print = function(value, _, py)
        printed[#printed + 1] = value
        positions[value] = py
    end
}, mouse = {getPosition = function() return pointerX, pointerY end}}
local router = require("modules.midi_router").create(function() return false end)
local monitor = require("modules.midi_monitor")
monitor.init({midiHandler = {
    getOutputHistory = router.getHistory, clearOutputHistory = router.clear,
    getCurrentOutputPortIndex = function() return -1 end
}})
local function rendered()
    printed, positions = {}, {}; monitor.draw(); return table.concat(printed, "\n")
end
local function contains(text, expected) assert(text:find(expected, 1, true), text) end
contains(rendered(), "F5 log")
assert(monitor.show())
contains(rendered(), "Waiting for sendMIDI() calls")
router.setRoute(4, false)
router.send(4, 0x90, 60, 100)
local text = rendered()
contains(text, "USB")
contains(text, "Note on ch1 C4 v100")
contains(text, "90 3C 64")
contains(text, "Captured")
assert(positions["USB"] == positions["Note on ch1 C4 v100"])
assert(positions["90 3C 64"] == positions["Note on ch1 C4 v100"], "one row per message")
assert(positions["Captured"] == positions["Note on ch1 C4 v100"])
contains(text, "No host output selected")
router.send(0, 0xF8)
contains(rendered(), "Ignored (mask 0)")
router.send(16, 0xF8)
contains(rendered(), "Invalid mask")
router.send(1, 0xF8)
contains(rendered(), "Captured (no host port)")

monitor.setPaused(true)
router.send(8, 0xB0, 7, 99)
assert(not rendered():find("B0 07 63", 1, true))
monitor.setPaused(false)
contains(rendered(), "B0 07 63")
for i = 1, 30 do router.send(4, 0xB0, 7, i) end
local bounds = monitor.getBounds()
pointerX, pointerY = bounds.x + 20, bounds.y + 100
assert(monitor.wheelmoved(0, 3))
assert(monitor.isPaused())
monitor.setPaused(false)
assert(not monitor.mousepressed(10, 10, 1), "outside clicks must reach emulator controls")
assert(monitor.mousepressed(bounds.x + 10, bounds.y + 10, 1))
assert(monitor.mousemoved(bounds.x + 50, bounds.y + 30))
assert(monitor.mousereleased(0, 0, 1))
bounds = monitor.getBounds()
assert(monitor.mousepressed(bounds.x + bounds.width - 95, bounds.y + 10, 1))
assert(#router.getHistory() == 0)
contains(rendered(), "Waiting for sendMIDI() calls")
assert(monitor.mousepressed(bounds.x + bounds.width - 20, bounds.y + 10, 1))
assert(not monitor.isVisible())
assert(monitor.mousepressed(600, 585, 1), "status badge opens the monitor")
assert(monitor.isVisible())
print("MIDI monitor tests passed")
