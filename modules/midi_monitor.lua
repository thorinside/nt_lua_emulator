-- Non-modal, draggable MIDI output log. Capture is independent of hardware.
local M = {}
local handler
local visible, paused, dragging = false, false, false
local frozen, scroll = nil, 0
local x, y, width, height
local dragX, dragY
local font
local names = {{1, "Breakout", "B"}, {2, "Select Bus", "S"}, {4, "USB", "U"}, {8, "Internal", "I"}}
local noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

function M.formatEvent(event)
    local mask, destinations, shortNames = event.destinations, {}, {}
    if type(mask) == "number" and mask == math.floor(mask) and mask >= 0 and mask <= 15 then
        for _, route in ipairs(names) do
            if math.floor(mask / route[1]) % 2 == 1 then
                destinations[#destinations + 1] = route[2]
                shortNames[#shortNames + 1] = route[3]
            end
        end
    end
    local target = #destinations > 0 and table.concat(destinations, "+") or "No destination"
    local bytes, hex = event.bytes or {}, {}
    for _, byte in ipairs(bytes) do
        hex[#hex + 1] = type(byte) == "number" and byte == math.floor(byte) and
            byte >= 0 and byte <= 255 and string.format("%02X", byte) or tostring(byte):sub(1, 12)
    end
    local status, description = bytes[1], "MIDI"
    if type(status) == "number" and status >= 128 and status < 240 then
        local kind, channel = math.floor(status / 16), status % 16 + 1
        local labels = {[8] = "Note off", [9] = "Note on", [10] = "Poly pressure",
                        [11] = "CC", [12] = "Program", [13] = "Pressure", [14] = "Pitch bend"}
        if kind == 9 and bytes[3] == 0 then kind = 8 end
        description = (labels[kind] or "MIDI") .. " ch" .. channel
        if (kind == 8 or kind == 9) and type(bytes[2]) == "number" and
            bytes[2] == math.floor(bytes[2]) and bytes[2] >= 0 and bytes[2] <= 127 then
            local note = noteNames[bytes[2] % 12 + 1] .. (math.floor(bytes[2] / 12) - 1)
            description = description .. " " .. note
            if bytes[3] ~= nil then description = description .. " v" .. tostring(bytes[3]) end
        else
            if bytes[2] ~= nil then description = description .. " " .. tostring(bytes[2]) end
            if bytes[3] ~= nil then description = description .. " " .. tostring(bytes[3]) end
        end
    elseif type(status) == "number" then
        local labels = {[0xF0] = "SysEx fragment", [0xF8] = "Clock", [0xFA] = "Start",
            [0xFB] = "Continue", [0xFC] = "Stop", [0xFE] = "Active sensing", [0xFF] = "Reset"}
        description = labels[status] or "System MIDI"
    end
    local delivery = {monitor = "Captured only - hardware output disabled",
        sent = "Sent to selected host output", unavailable = "No host output available - captured"}
    local result = ({monitor = "Captured", sent = "Sent", unavailable = "Captured (no host port)",
                     ignored = "Ignored (mask 0)"})[event.delivery] or "Invalid bytes"
    if event.delivery == "invalid" then
        if event.reason and event.reason:find("Destination", 1, true) then result = "Invalid mask"
        elseif event.reason and event.reason:find("1 to 3", 1, true) then result = "Need 1-3 bytes" end
    end
    local seconds = (event.time or 0) % 3600
    return {
        time = string.format("%02d:%06.3f", math.floor(seconds / 60), seconds % 60),
        destination = #destinations == 4 and "All" or
                      (#destinations > 1 and table.concat(shortNames, "+") or destinations[1] or "None"),
        message = description, bytes = table.concat(hex, " "), result = result,
        detail = target .. " | " .. description .. " | " .. table.concat(hex, " ") .. " | " ..
                 (event.reason or delivery[event.delivery] or "Captured")
    }
end

function M.init(deps)
    handler = assert(deps.midiHandler)
    visible, paused, dragging, frozen, scroll = false, false, false, nil, 0
    x, y, font = nil, nil, nil
end
local function layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    width, height = math.min(640, sw - 16), math.min(280, sh - 16)
    x = math.max(8, math.min(x or (sw - width - 8), sw - width - 8))
    y = math.max(8, math.min(y or (sh - height - 8), sh - height - 8))
end
local function history()
    return paused and frozen or handler.getOutputHistory()
end
local function inside(px, py)
    layout()
    return visible and px >= x and px <= x + width and py >= y and py <= y + height
end
function M.show()
    if not handler then return false end
    visible = true
    layout()
    return true
end
function M.hide() visible, dragging = false, false end
function M.toggle() if visible then M.hide() else M.show() end end
function M.isVisible() return visible end
function M.isPaused() return paused end
function M.setPaused(value)
    paused = not not value
    frozen = paused and handler.getOutputHistory() or nil
    scroll = 0
end
function M.clear()
    handler.clearOutputHistory()
    frozen, scroll = paused and {} or nil, 0
end
function M.getBounds()
    layout()
    return {x = x, y = y, width = width, height = height}
end
function M.draw()
    if not handler then return end
    font = font or love.graphics.newFont(12)
    love.graphics.push("all")
    love.graphics.setFont(font)
    if not visible then
        local events = handler.getOutputHistory()
        local count = #events > 0 and events[#events].id or 0
        love.graphics.setColor(0.6, 0.85, 0.9, 1)
        love.graphics.print("MIDI out: " .. count .. " calls | F5 log", love.graphics.getWidth() - 250,
                            love.graphics.getHeight() - 20)
        love.graphics.pop()
        return
    end
    layout()
    love.graphics.setColor(0.08, 0.1, 0.13, 0.97)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.4, 0.75, 0.85, 1)
    love.graphics.rectangle("line", x, y, width, height)
    love.graphics.print("MIDI OUTPUT LOG  [F5]", x + 10, y + 9)
    love.graphics.print(paused and "Resume" or "Pause", x + width - 180, y + 9)
    love.graphics.print("Clear", x + width - 105, y + 9)
    love.graphics.print("X", x + width - 24, y + 9)
    love.graphics.setColor(0.75, 0.8, 0.85, 1)
    local port = handler.getCurrentOutputPortIndex()
    local portText = port < 0 and "No host output selected; capture is active" or "Host output port " .. (port + 1)
    love.graphics.print(paused and "View paused; script and capture still running" or portText, x + 10, y + 30)
    local events = history()
    local rows = math.max(1, math.floor((height - 98) / 20))
    scroll = math.max(0, math.min(scroll, math.max(0, #events - rows)))
    local usable = width - 20
    local edges = {0, 0.115, 0.25, 0.52, 0.66, 1}
    local headers = {"Time", "Destination", "Message", "Bytes", "Result"}
    local function cell(text, column, top)
        local left = x + 10 + math.floor(usable * edges[column])
        local cellWidth = math.floor(usable * (edges[column + 1] - edges[column])) - 6
        local fitted = text
        while #fitted > 0 and font:getWidth(fitted) > cellWidth do fitted = fitted:sub(1, -2) end
        if fitted ~= text and #fitted > 3 then fitted = fitted:sub(1, -4) .. "..." end
        love.graphics.setScissor(left, top, math.max(1, cellWidth), 19)
        love.graphics.print(fitted, left, top)
    end
    love.graphics.setColor(0.16, 0.2, 0.24, 1)
    love.graphics.rectangle("fill", x + 8, y + 50, width - 16, 20)
    love.graphics.setColor(0.7, 0.8, 0.85, 1)
    for column, title in ipairs(headers) do cell(title, column, y + 53) end
    love.graphics.setScissor(x + 8, y + 72, width - 16, math.max(1, height - 98))
    if #events == 0 then
        love.graphics.setColor(1, 0.85, 0.4, 1)
        love.graphics.print("Waiting for sendMIDI() calls...", x + 12, y + 84)
        love.graphics.setColor(0.8, 0.85, 0.9, 1)
        love.graphics.print("Demo: press A (button 2). F4 configures routing.", x + 12, y + 96)
        love.graphics.print("No MIDI hardware or output port is needed for capture.", x + 12, y + 116)
    end
    local pointerX, pointerY = love.mouse.getPosition()
    local hovered
    for row = 1, rows do
        local event = events[#events - scroll - row + 1]
        if not event then break end
        local entry = M.formatEvent(event)
        local lineY = y + 72 + (row - 1) * 20
        local warning = event.delivery == "invalid" or event.delivery == "ignored" or event.delivery == "unavailable"
        love.graphics.setScissor(x + 8, lineY, width - 16, 20)
        love.graphics.setColor(row % 2 == 0 and 0.12 or 0.09, 0.14, 0.17, 1)
        love.graphics.rectangle("fill", x + 8, lineY, width - 16, 20)
        local values = {entry.time, entry.destination, entry.message, entry.bytes, entry.result}
        for column, value in ipairs(values) do
            if column == 1 then love.graphics.setColor(0.55, 0.65, 0.7, 1)
            elseif column == 4 then love.graphics.setColor(0.6, 0.85, 0.95, 1)
            elseif column == 5 then love.graphics.setColor(warning and 1 or 0.65, warning and 0.75 or 0.9, warning and 0.4 or 0.75, 1)
            else love.graphics.setColor(0.9, 0.93, 0.95, 1) end
            cell(value, column, lineY + 2)
        end
        if pointerX >= x and pointerX <= x + width and pointerY >= lineY and pointerY < lineY + 20 then
            hovered = entry.detail
        end
    end
    love.graphics.setScissor(x + 8, y + height - 20, width - 16, 20)
    love.graphics.setColor(0.6, 0.75, 0.8, 1)
    love.graphics.print(hovered or "Controls active | drag title | wheel: pause/scroll | hover: details | F4: routing", x + 10, y + height - 17)
    love.graphics.setScissor()
    love.graphics.pop()
end
function M.mousepressed(px, py, button)
    if not visible then
        if button == 1 and px >= love.graphics.getWidth() - 250 and
            py >= love.graphics.getHeight() - 22 then return M.show() end
        return false
    end
    if not inside(px, py) then return false end
    if button ~= 1 then return true end
    if py <= y + 27 then
        if px >= x + width - 38 then M.hide()
        elseif px >= x + width - 115 then M.clear()
        elseif px >= x + width - 190 then M.setPaused(not paused)
        else dragging, dragX, dragY = true, px - x, py - y end
    end
    return true
end
function M.mousemoved(px, py)
    if not dragging then return false end
    x, y = px - dragX, py - dragY
    layout()
    return true
end
function M.mousereleased(_, _, button)
    if button == 1 and dragging then dragging = false; return true end
    return false
end
function M.wheelmoved(_, delta)
    local px, py = love.mouse.getPosition()
    if not inside(px, py) then return false end
    if not paused then M.setPaused(true) end
    scroll = scroll + delta
    return true
end
return M
