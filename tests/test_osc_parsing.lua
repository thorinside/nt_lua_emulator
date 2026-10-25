-- No real ports are opened. Test the public OSC server parser and receive path.
local packet, delivered, closed, failBind, failConnect = nil, {}, 0, false, false
package.loaded.socket = {udp = function() return {
    setpeername = function() if failConnect then return nil, "network unavailable" end; return true end,
    setsockname = function() if failBind then return nil, "busy" end; return true end,
    settimeout = function() end,
    receivefrom = function() local data = packet; packet = nil; return data, "127.0.0.1", 1234 end,
    close = function() closed = closed + 1 end
} end}
local osc = require("modules.osc")
local client = osc.new()
local server = client.create_server(9000, function(address, args)
    if address == "/throw" then error("bad callback") end
    delivered[#delivered + 1] = {address, args}
end)
local function str(s) return s .. string.rep("\0", 4 - #s % 4) end
local function integer(n)
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
                       math.floor(n / 256) % 256, n % 256)
end
local function message(address) return str(address) .. str(",i") .. integer(42) end
local function bundle(...)
    local result = "#bundle\0" .. string.rep("\0", 7) .. "\1"
    for _, data in ipairs({...}) do result = result .. integer(#data) .. data end
    return result
end
local address, args = server.parse_message(message("/test"))
assert(address == "/test" and args[1] == 42)
for _, data in ipairs({"", "abcd", "/x\0", "/x\0X,i\0\0" .. integer(1),
    str("not-an-address") .. str(","), "#bundle\0", bundle() .. integer(0),
    bundle() .. integer(3) .. "abc\0", bundle() .. integer(100),
    message("/test") .. "xxxx", str("/test") .. str(",i"),
    bundle(message("/valid"), "bad!")}) do
    local ok, result, err = pcall(server.parse_message, data)
    assert(ok and result == nil and type(err) == "string", "must reject malformed packet without throwing")
end
local nested = message("/deep")
for i = 1, 100 do nested = bundle(nested) end
local result, err = server.parse_message(nested)
assert(result == nil and err:find("nesting", 1, true))
packet = bundle(message("/one"), bundle(message("/two")))
assert(server.update() == "#bundle")
assert(#delivered == 2 and delivered[1][1] == "/one" and delivered[2][1] == "/two")
packet = bundle(message("/valid"), "bad!")
assert(server.update() == nil); assert(#delivered == 2, "no partial malformed-bundle delivery")
packet = message("/throw")
local ok, callbackError = server.update()
assert(ok == nil and callbackError:find("callback failed", 1, true))
packet = message("/recovered")
assert(server.update() == "/recovered", "callback error must not disable receiving")
-- Deterministic byte noise exercises lengths, padding, and tags without a socket.
local seed = 123
for length = 0, 256 do
    local bytes = {}
    for i = 1, length do seed = (seed * 16807) % 2147483647; bytes[i] = string.char(seed % 256) end
    assert(pcall(server.parse_message, table.concat(bytes)))
end
failBind = true
assert(not pcall(client.create_server, 9000)); assert(closed == 1, "failed bind must close its socket")
failConnect = true
assert(not pcall(osc.new)); assert(closed == 2, "failed connect must close its socket")
-- Optional OSC must not prevent the emulator from starting or retrying later.
package.loaded["modules.config"] = {load = function() return {osc = {
    enabled = true, host = "127.0.0.1", port = 8000}}
end}
package.loaded["modules.emulator"] = {}
local oscClient = require("modules.osc_client")
assert(oscClient.init() == false); assert(not oscClient.isEnabled())
assert(oscClient.toggle() == false); assert(not oscClient.isEnabled())
failConnect = false
oscClient.toggle(); assert(oscClient.isEnabled())
oscClient.toggle(); assert(not oscClient.isEnabled())
print("OSC malformed-packet and connection recovery tests passed")
