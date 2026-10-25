-- Deterministic test device at every valid I2C address. Not an emulation of
-- any manufacturer's protocol: command {register, data...}, getter {register}.
local M = {}
function M.create()
    local devices, history = {}, {}
    local function record(kind, address, bytes, length)
        local copy = {}
        for i, value in ipairs(bytes) do copy[i] = value end
        history[#history + 1] = {kind = kind, address = address, bytes = copy, length = length}
        if #history > 64 then table.remove(history, 1) end
    end
    return {
        sendCommand = function(address, bytes)
            record("write", address, bytes)
            local registers = devices[address] or {}
            devices[address] = registers
            if not bytes[1] then return end
            for i = 2, #bytes do registers[(bytes[1] + i - 2) % 256] = bytes[i] end
        end,
        get = function(address, length, bytes)
            record("read", address, bytes, length)
            local registers = devices[address] or {}
            local result = {}
            for i = 1, length do result[i] = registers[((bytes[1] or 0) + i - 1) % 256] or 0 end
            return result
        end,
        getHistory = function()
            -- Return snapshots so monitors cannot alter device state/history.
            local result = {}
            for i, event in ipairs(history) do
                local bytes = {}
                for j, byte in ipairs(event.bytes) do bytes[j] = byte end
                result[i] = {kind = event.kind, address = event.address,
                             length = event.length, bytes = bytes}
            end
            return result
        end
    }
end
return M
