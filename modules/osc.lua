-- osc.lua - Open Sound Control library for Lua
-- Compatibility with LÖVE and standard Lua
-- Try to load socket library based on environment
local socket
if love and love.system then
    -- Running in LÖVE
    socket = require("socket")
else
    -- Standard Lua environment
    socket = require("socket")
end

local osc = {
    _VERSION = "1.0.0",
    _DESCRIPTION = "Open Sound Control (OSC) implementation for Lua"
}

-- Global debug flag (will be checked in the library functions)
local debugEnabled = false

-- Function to enable/disable debugging
function enableDebug(enable) debugEnabled = enable == true end

-- Constructor for a new OSC client
function osc.new(host, port)
    local client = {
        host = host or "127.0.0.1",
        port = port or 8000,
        udp = assert(socket.udp())
    }

    -- Connect to the specified host and port
    local success, err = client.udp:setpeername(client.host, client.port)
    if not success then
        error("Failed to connect to OSC server: " .. tostring(err))
    end

    -- Convert float to big-endian bytes (IEEE 754 format)
    function client.float_to_bytes(num)
        -- Log float conversion if debug is enabled
        if debugEnabled then
            print(string.format("[OSC DEBUG] Converting float %f to IEEE 754",
                                num))
        end

        -- Handle special cases
        if num == 0 then
            if debugEnabled then print("[OSC DEBUG] Float is zero") end
            return string.char(0, 0, 0, 0) -- positive zero
        elseif num == -0 then
            if debugEnabled then
                print("[OSC DEBUG] Float is negative zero")
            end
            return string.char(0x80, 0, 0, 0) -- negative zero
        elseif num ~= num then
            if debugEnabled then print("[OSC DEBUG] Float is NaN") end
            return string.char(0x7F, 0xC0, 0, 0) -- NaN
        elseif num == math.huge then
            if debugEnabled then
                print("[OSC DEBUG] Float is positive infinity")
            end
            return string.char(0x7F, 0x80, 0, 0) -- positive infinity
        elseif num == -math.huge then
            if debugEnabled then
                print("[OSC DEBUG] Float is negative infinity")
            end
            return string.char(0xFF, 0x80, 0, 0) -- negative infinity
        end

        -- Sign bit
        local sign = 0
        if num < 0 then
            sign = 0x80
            num = -num
        end

        -- Get mantissa and exponent using frexp
        local mantissa, exponent = math.frexp(num)

        -- Adjust for IEEE 754 format
        exponent = exponent - 1
        mantissa = mantissa * 2 - 1

        -- IEEE 754 uses biased exponent (bias of 127 for single precision)
        local biasedExponent = exponent + 127

        -- Handle denormalized numbers
        if biasedExponent <= 0 then
            -- Denormalized number
            mantissa = mantissa * math.pow(2, biasedExponent)
            biasedExponent = 0
        elseif biasedExponent >= 255 then
            -- Should not happen as we handled infinity already
            biasedExponent = 255
            mantissa = 0
        end

        -- Convert mantissa to 23-bit integer (mantissa precision in single precision)
        local mantissaBits = math.floor(mantissa * 0x800000 + 0.5)

        -- Combine into IEEE 754 format
        -- Byte 1: Sign bit (1 bit) + high bits of exponent (7 bits)
        -- Byte 2: Low bit of exponent (1 bit) + high bits of mantissa (7 bits)
        -- Byte 3-4: Remaining bits of mantissa (16 bits)
        local byte1 = sign + math.floor(biasedExponent / 2)
        local byte2 = (biasedExponent % 2) * 0x80 +
                          math.floor(mantissaBits / 0x10000)
        local byte3 = math.floor(mantissaBits / 0x100) % 0x100
        local byte4 = mantissaBits % 0x100

        if debugEnabled then
            print(string.format(
                      "[OSC DEBUG] Float %f encoded as bytes: %02X %02X %02X %02X",
                      num, byte1, byte2, byte3, byte4))
        end

        -- Return as big-endian bytes
        return string.char(byte1, byte2, byte3, byte4)
    end

    -- Convert int32 to big-endian bytes
    function client.int32_to_bytes(num)
        num = math.floor(num) -- Ensure it's an integer
        if num < 0 then
            num = 0x100000000 + num -- Convert negative to two's complement
        end
        return string.char(math.floor(num / 0x1000000) % 0x100,
                           math.floor(num / 0x10000) % 0x100,
                           math.floor(num / 0x100) % 0x100, num % 0x100)
    end

    -- Convert string to OSC string (null-terminated, padded to 4-byte boundary)
    function client.string_to_osc(str)
        -- Ensure str is a string
        if type(str) ~= "string" then
            error("Expected string but got " .. type(str))
        end

        local len = #str
        local padding = 4 - ((len + 1) % 4)
        if padding == 4 then padding = 0 end
        return str .. string.rep("\0", padding + 1)
    end

    -- Pad any data to 4-byte boundary
    function client.pad_to_4(data)
        -- Ensure data is a string
        if type(data) ~= "string" then
            error("Expected string data but got " .. type(data))
        end

        local padding = 4 - (#data % 4)
        if padding == 4 then padding = 0 end
        return data .. string.rep("\0", padding)
    end

    -- Create an OSC message with multiple arguments
    function client.create_message(address, ...)
        -- Ensure address is a string
        if type(address) ~= "string" then
            error("OSC address must be a string, got " .. type(address))
        end

        -- Validate address format
        if not string.match(address, "^/") then
            error("OSC address must start with /")
        end

        -- Pad address to 4-byte boundary
        local message = client.string_to_osc(address)

        -- Build type tag and data
        local args = {...}
        local type_tag = ","
        local data = ""

        for _, arg in ipairs(args) do
            local arg_type = type(arg)

            if arg_type == "number" then
                if math.floor(arg) == arg then
                    -- Integer
                    type_tag = type_tag .. "i"
                    data = data .. client.int32_to_bytes(arg)
                else
                    -- Float
                    type_tag = type_tag .. "f"
                    data = data .. client.float_to_bytes(arg)
                end
            elseif arg_type == "string" then
                -- String
                type_tag = type_tag .. "s"
                data = data .. client.string_to_osc(arg)
            elseif arg_type == "boolean" then
                -- Boolean (T or F)
                if arg then
                    type_tag = type_tag .. "T"
                else
                    type_tag = type_tag .. "F"
                end
                -- T and F have no data bytes
            elseif arg == nil then
                -- Nil/None
                type_tag = type_tag .. "N"
                -- N has no data bytes
            else
                error("Unsupported OSC argument type: " .. arg_type)
            end
        end

        -- Add type tag to message
        message = message .. client.string_to_osc(type_tag)

        -- Add data to message
        message = message .. data

        return message
    end

    -- Send a raw OSC message
    function client.send_raw(message) return client.udp:send(message) end

    -- Send an OSC message with multiple arguments
    function client.send(address, ...)
        local message = client.create_message(address, ...)
        return client.send_raw(message)
    end

    -- Send a float value to an OSC address
    function client.send_float(address, value)
        return client.send(address, value)
    end

    -- Send an integer value to an OSC address
    function client.send_int(address, value)
        return client.send(address, math.floor(value))
    end

    -- Send a string value to an OSC address
    function client.send_string(address, value)
        return client.send(address, tostring(value))
    end

    -- Create an OSC bundle
    function client.create_bundle(timetag, ...)
        local bundle = "#bundle\0" -- OSC bundle identifier

        -- Add timetag (8 bytes, default to immediate)
        if timetag then
            -- Convert timetag to OSC format (NTP timestamp)
            error("Custom timetags not implemented yet")
        else
            -- Immediate execution (0x0000000000000001)
            bundle = bundle .. string.char(0, 0, 0, 0, 0, 0, 0, 1)
        end

        -- Add each element (message or nested bundle)
        local elements = {...}
        for _, element in ipairs(elements) do
            -- Add size of element as int32
            bundle = bundle .. client.int32_to_bytes(#element)
            -- Add element data
            bundle = bundle .. element
        end

        return bundle
    end

    -- Send an OSC bundle
    function client.send_bundle(timetag, ...)
        local bundle = client.create_bundle(timetag, ...)
        return client.send_raw(bundle)
    end

    -- Setup OSC server to receive messages
    function client.create_server(receive_port, callback)
        local server = {}
        server.udp = socket.udp()

        local success, err = server.udp:setsockname("*", receive_port)
        if not success then
            error("Failed to create OSC server: " .. tostring(err))
        end

        server.udp:settimeout(0) -- Non-blocking

        -- Utility function to extract null-terminated string
        function server.extract_string(data, pos)
            local end_pos = data:find("\0", pos)
            if not end_pos then
                return nil, "String not null-terminated"
            end

            local str = data:sub(pos, end_pos - 1)
            -- Calculate position after padding
            local next_pos = pos + math.ceil((end_pos - pos + 1) / 4) * 4
            return str, next_pos
        end

        -- Function to parse OSC messages
        function server.parse_message(data)
            -- Check if it's a bundle
            if data:sub(1, 8) == "#bundle\0" then
                -- Parse bundle
                return server.parse_bundle(data)
            end

            -- Extract address pattern
            local address, pos = server.extract_string(data, 1)
            if not address then
                return nil, "Invalid OSC message: " .. tostring(pos)
            end

            -- Extract type tag
            local type_tag, pos = server.extract_string(data, pos)
            if not type_tag or type_tag:sub(1, 1) ~= "," then
                return nil, "Invalid type tag"
            end

            -- Parse arguments based on type tag
            local args = {}

            for i = 2, #type_tag do
                local t = type_tag:sub(i, i)

                if t == "i" then
                    -- Integer
                    if pos + 3 > #data then
                        return nil, "Message too short for int32"
                    end

                    local b1, b2, b3, b4 = data:byte(pos, pos + 3)
                    local int_val = (b1 * 0x1000000) + (b2 * 0x10000) +
                                        (b3 * 0x100) + b4

                    -- Handle negative numbers (two's complement)
                    if int_val >= 0x80000000 then
                        int_val = int_val - 0x100000000
                    end

                    table.insert(args, int_val)
                    pos = pos + 4

                elseif t == "f" then
                    -- Float (IEEE 754 format)
                    if pos + 3 > #data then
                        return nil, "Message too short for float"
                    end

                    -- Read 4 bytes for IEEE 754 single precision float
                    local b1, b2, b3, b4 = data:byte(pos, pos + 3)

                    -- Extract components from IEEE 754 representation
                    local sign = (b1 >= 128) and -1 or 1
                    local exponent = math.floor(b1 % 128) * 2 +
                                         math.floor(b2 / 128)
                    local mantissa = ((b2 % 128) * 65536) + (b3 * 256) + b4

                    local float_val

                    if exponent == 0 and mantissa == 0 then
                        -- Zero
                        float_val = sign * 0
                    elseif exponent == 0xFF then
                        if mantissa == 0 then
                            -- Infinity
                            float_val = sign * math.huge
                        else
                            -- NaN
                            float_val = 0 / 0
                        end
                    elseif exponent == 0 then
                        -- Denormalized
                        float_val = sign * mantissa * 2 ^ (-126 - 23)
                    else
                        -- Normalized
                        float_val = sign * (1 + mantissa / 0x800000) * 2 ^
                                        (exponent - 127)
                    end

                    table.insert(args, float_val)
                    pos = pos + 4

                elseif t == "s" then
                    -- String
                    local str, next_pos = server.extract_string(data, pos)
                    if not str then return nil, next_pos end

                    table.insert(args, str)
                    pos = next_pos

                elseif t == "T" then
                    -- True
                    table.insert(args, true)

                elseif t == "F" then
                    -- False
                    table.insert(args, false)

                elseif t == "N" then
                    -- Nil
                    table.insert(args, nil)

                else
                    -- Unsupported type, skip it
                    return nil, "Unsupported argument type: " .. t
                end
            end

            return address, args
        end

        -- Function to parse OSC bundles
        function server.parse_bundle(data)
            -- Check bundle header
            if data:sub(1, 8) ~= "#bundle\0" then
                return nil, "Not an OSC bundle"
            end

            -- Skip timetag (8 bytes)
            local pos = 17 -- 8 (header) + 8 (timetag) + 1

            -- Parse bundle elements
            local elements = {}

            while pos <= #data do
                -- Read element size
                if pos + 3 > #data then
                    return nil, "Bundle too short for element size"
                end

                local b1, b2, b3, b4 = data:byte(pos, pos + 3)
                local size = (b1 * 0x1000000) + (b2 * 0x10000) + (b3 * 0x100) +
                                 b4
                pos = pos + 4

                -- Read element data
                if pos + size - 1 > #data then
                    return nil, "Bundle too short for element data"
                end

                local element_data = data:sub(pos, pos + size - 1)
                local element_address, element_args =
                    server.parse_message(element_data)

                if element_address then
                    table.insert(elements, {
                        address = element_address,
                        args = element_args
                    })
                end

                pos = pos + size
            end

            return "#bundle", elements
        end

        -- Update function to check for new messages
        function server.update()
            local data, ip, port = server.udp:receivefrom()
            if data then
                local address, args = server.parse_message(data)

                if address and callback then
                    if address == "#bundle" then
                        -- Handle bundle
                        for _, element in ipairs(args) do
                            callback(element.address, element.args, ip, port)
                        end
                    else
                        -- Handle single message
                        callback(address, args, ip, port)
                    end
                end

                return address, args
            end

            return nil
        end

        -- Close the server
        function server.close() server.udp:close() end

        return server
    end

    -- Close UDP connection
    function client.close() client.udp:close() end

    return client
end

return osc
