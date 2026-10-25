-- Logical NT destinations share the selected host output, or are capture-only.
-- Internal is deliberately not looped back: a script could feed itself forever.
local M = {}
local unpackValues = table.unpack or unpack
function M.create(send, getTime)
    getTime = getTime or os.clock
    local destinations = {
        {mask = 1, name = "Breakout", forward = true, count = 0},
        {mask = 2, name = "Select Bus", forward = true, count = 0},
        {mask = 4, name = "USB", forward = true, count = 0},
        {mask = 8, name = "Internal", forward = false, count = 0}
    }
    local capacity = 128
    local history, head, size = {}, 1, 0
    local sequence, revision = 0, 0
    local function copyBytes(bytes)
        local result = {}
        for i, byte in ipairs(bytes) do result[i] = byte end
        return result
    end
    local function record(mask, bytes, delivery, reason)
        sequence, revision = sequence + 1, revision + 1
        local index = (head + size - 1) % capacity + 1
        history[index] = {id = sequence, time = getTime(), destinations = mask,
            bytes = copyBytes(bytes), delivery = delivery, reason = reason, forwarded = delivery == "sent"}
        if size < capacity then size = size + 1
        else head = head % capacity + 1 end
    end
    local router = {}
    function router.send(mask, ...)
        local count, bytes = select("#", ...), {}
        -- Diagnostic snapshots must not retain arbitrary script-owned tables.
        for i = 1, math.min(count, 4) do
            local byte = select(i, ...)
            bytes[i] = type(byte) == "number" and byte or type(byte)
        end
        if type(mask) ~= "number" or mask ~= math.floor(mask) or mask < 0 or mask > 15 then
            record(type(mask) == "number" and mask or -1, bytes, "invalid", "Destination mask must be an integer from 0 to 15")
            return false
        end
        if count < 1 or count > 3 then
            record(mask, bytes, "invalid", "Expected 1 to 3 MIDI bytes")
            return false
        end
        for _, byte in ipairs(bytes) do
            if type(byte) ~= "number" or byte ~= math.floor(byte) or byte < 0 or byte > 255 then
                record(mask, bytes, "invalid", "MIDI bytes must be integers from 0 to 255")
                return false
            end
        end
        if mask == 0 then
            record(mask, bytes, "ignored", "Destination mask 0 selects no outputs")
            return true
        end
        local forward = false
        for _, destination in ipairs(destinations) do
            if math.floor(mask / destination.mask) % 2 == 1 then
                destination.count = destination.count + 1
                destination.last = copyBytes(bytes)
                forward = forward or destination.forward
            end
        end
        -- One host port stands in for multiple transports. Do not duplicate notes.
        local forwarded = forward and send and send(unpackValues(bytes)) or false
        record(mask, bytes, not forward and "monitor" or (forwarded and "sent" or "unavailable"))
        return true
    end
    function router.setRoute(mask, forward)
        for _, destination in ipairs(destinations) do
            if destination.mask == mask then
                destination.forward = not not forward
                return true
            end
        end
        return false
    end
    function router.getRoutes()
        local result = {}
        for i, destination in ipairs(destinations) do
            result[i] = {mask = destination.mask, name = destination.name,
                         forward = destination.forward, count = destination.count,
                         last = destination.last and copyBytes(destination.last) or nil}
        end
        return result
    end
    -- Return only the newest requested rows, still ordered oldest to newest.
    -- Snapshots never expose the ring buffer or its mutable byte tables.
    function router.getHistory(limit)
        local count = math.max(0, math.min(size, math.floor(limit or size)))
        local result = {}
        for i = 1, count do
            local event = history[(head + size - count + i - 2) % capacity + 1]
            result[i] = {id = event.id, time = event.time, destinations = event.destinations,
                bytes = copyBytes(event.bytes), delivery = event.delivery, reason = event.reason,
                forwarded = event.forwarded}
        end
        return result
    end
    -- Allocation-free change detection for the monitor, including after clear.
    function router.getHistoryState() return revision, sequence end
    function router.clear()
        history, head, size, sequence = {}, 1, 0, 0
        revision = revision + 1
        for _, destination in ipairs(destinations) do destination.count, destination.last = 0, nil end
    end
    return router
end
return M
