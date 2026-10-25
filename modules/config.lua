-- Validated application configuration. Never return shared default tables.
local json = require("lib.dkjson")
local config = {}
local defaults = {
    osc = {enabled = false, host = "127.0.0.1", port = 8000, address = "/dnt",
           sendInterval = 0.001, outputFormat = "single"},
    script = {path = "test_script.lua"},
    minimalMode = false,
    midi = {enabled = false, selectedInput = -1, selectedOutput = -1,
            destinationRoutes = {}}
}
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function merge(source, template)
    local result = {}
    source = type(source) == "table" and source or {}
    for key, default in pairs(template) do
        local value = source[key]
        if type(default) == "table" then result[key] = merge(value, default)
        elseif type(value) == type(default) and (type(value) ~= "number" or finite(value)) then
            result[key] = value -- Preserve explicit false, not just truthy values.
        else result[key] = default end
    end
    return result
end
function config.load()
    local source = {}
    local file = io.open("config.json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        local ok, decoded, _, err = pcall(json.decode, content)
        if ok and not err and type(decoded) == "table" then source = decoded
        else print("Invalid config.json; using defaults") end
    end
    local result = merge(source, defaults)
    local osc, midi = result.osc, result.midi
    if osc.port < 1 or osc.port > 65535 or osc.port % 1 ~= 0 then osc.port = defaults.osc.port end
    if osc.sendInterval <= 0 then osc.sendInterval = defaults.osc.sendInterval end
    if osc.host == "" then osc.host = defaults.osc.host end
    if osc.address:sub(1, 1) ~= "/" then osc.address = defaults.osc.address end
    if osc.outputFormat ~= "single" and osc.outputFormat ~= "array" then osc.outputFormat = "single" end
    for _, key in ipairs({"selectedInput", "selectedOutput"}) do
        if midi[key] < -1 or midi[key] % 1 ~= 0 then midi[key] = -1 end
    end
    local routes = type(source.midi) == "table" and source.midi.destinationRoutes
    if type(routes) == "table" then
        for _, mask in ipairs({"1", "2", "4", "8"}) do
            if type(routes[mask]) == "boolean" then midi.destinationRoutes[mask] = routes[mask] end
        end
    end
    return result
end
function config.save(value)
    return require("modules.json_store").save("config.json", value)
end
return config
