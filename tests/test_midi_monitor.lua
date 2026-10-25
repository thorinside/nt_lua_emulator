local printed, positions = {}, {}
local pointerX, pointerY = 0, 0
local snapshots, lastLimit, formatted = 0, nil, 0
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
    getOutputHistory = function(limit)
        snapshots, lastLimit = snapshots + 1, limit
        return router.getHistory(limit)
    end,
    getOutputHistoryState = router.getHistoryState,
    clearOutputHistory = router.clear,
    getCurrentOutputPortIndex = function() return -1 end
}})
local originalFormat = monitor.formatEvent
monitor.formatEvent = function(event)
    formatted = formatted + 1
    return originalFormat(event)
end
local function rendered()
    printed, positions = {}, {}; monitor.draw(); return table.concat(printed, "\n")
end
local function contains(text, expected) assert(text:find(expected, 1, true), text) end
contains(rendered(), "F5 log")
for i = 1, 100 do rendered() end
assert(snapshots == 0, "a hidden monitor must not copy the MIDI history")
for i = 1, 10000 do router.send(8, 0xF8) end
contains(rendered(), "MIDI out: 10000 calls")
assert(snapshots == 0, "hidden high-traffic capture must not allocate history snapshots")
router.clear()
contains(rendered(), "MIDI out: 0 calls")
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
local previousSnapshots, previousFormatted = snapshots, formatted
for i = 1, 100 do rendered() end
assert(snapshots == previousSnapshots, "unchanged history must reuse its snapshot")
assert(formatted == previousFormatted, "unchanged rows must not be decoded every frame")
router.send(0, 0xF8)
contains(rendered(), "Ignored (mask 0)")
router.send(16, 0xF8)
contains(rendered(), "Invalid mask")
router.send(1, 0xF8)
contains(rendered(), "Captured (no host port)")

monitor.setPaused(true)
previousSnapshots = snapshots
router.send(8, 0xB0, 7, 99)
assert(not rendered():find("B0 07 63", 1, true))
assert(snapshots == previousSnapshots, "paused drawing must not read live history")
monitor.setPaused(false)
contains(rendered(), "B0 07 63")
for i = 1, 10000 do router.send(4, 0xB0, 7, i % 128) end
contains(rendered(), "B0 07 10") -- The newest message survives ring-buffer wraparound.
assert(lastLimit == 9, "live drawing must copy only the nine visible rows")
assert(#router.getHistory() == 128, "capture memory must remain bounded under heavy traffic")
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
-- An external clear followed by reused IDs must invalidate cached row text.
router.clear()
router.send(4, 0x90, 61, 70)
contains(rendered(), "Note on ch1 C#4 v70")
router.clear()
router.send(4, 0x90, 62, 71)
contains(rendered(), "Note on ch1 D4 v71")
print("MIDI monitor tests passed")
