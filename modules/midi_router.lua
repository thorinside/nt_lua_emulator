-- Logical NT destinations share the selected host output, or are monitor-only.
-- Internal is deliberately not looped back: a script could feed itself forever.
local M = {}
local unpackValues = table.unpack or unpack
function M.create(send)
    local destinations = {
        {mask = 1, name = "Breakout", forward = true, count = 0},
        {mask = 2, name = "Select Bus", forward = true, count = 0},
        {mask = 4, name = "USB", forward = true, count = 0},
        {mask = 8, name = "Internal", forward = false, count = 0}
    }
    local history = {}
    local function copyBytes(bytes)
        local result = {}
        for i, byte in ipairs(bytes) do result[i] = byte end
        return result
    end
    local router = {}
    function router.send(mask, ...)
        if type(mask) ~= "number" or mask ~= math.floor(mask) or mask < 0 or mask > 15 then
            return false
        end
        local bytes = {...}
        if #bytes < 1 or #bytes > 3 then return false end
        for _, byte in ipairs(bytes) do
            if type(byte) ~= "number" or byte ~= math.floor(byte) or byte < 0 or byte > 255 then
                return false
            end
        end
        if mask == 0 then return true end
        local forward = false
        for _, destination in ipairs(destinations) do
            if math.floor(mask / destination.mask) % 2 == 1 then
                destination.count = destination.count + 1
                destination.last = copyBytes(bytes)
                forward = forward or destination.forward
            end
        end
        -- One host port stands in for multiple transports. Never duplicate notes
        -- when the caller specifies more than one forwarded destination.
        local forwarded = forward and send and send(unpackValues(bytes)) or false
        history[#history + 1] = {destinations = mask, bytes = copyBytes(bytes), forwarded = not not forwarded}
        if #history > 128 then table.remove(history, 1) end
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
    function router.getHistory()
        local result = {}
        for i, event in ipairs(history) do
            result[i] = {destinations = event.destinations, bytes = copyBytes(event.bytes),
                         forwarded = event.forwarded}
        end
        return result
    end
    return router
end
return M
