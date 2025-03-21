-- config.lua
local json = require("lib.dkjson")
local config = {}

-- Default configuration
local defaultConfig = {
    osc = {
        enabled = false,
        host = "127.0.0.1",
        port = 8000,
        address = "/dnt",
        sendInterval = 0.001,
        outputFormat = "single" -- "array" or "single"
    },
    script = {path = "test_script.lua"}
}

-- Load configuration from file
function config.load()
    local file = io.open("config.json", "r")
    if not file then
        print("No config.json found, using defaults")
        return defaultConfig
    end

    local content = file:read("*all")
    file:close()

    local success, userConfig =
        pcall(function() return json.decode(content) end)

    if not success then
        print("Error parsing config.json:", userConfig)
        print("Using default configuration")
        return defaultConfig
    end

    -- Merge user config with defaults
    local mergedConfig = {}
    for k, v in pairs(defaultConfig) do
        if type(v) == "table" then
            mergedConfig[k] = {}
            for sk, sv in pairs(v) do
                mergedConfig[k][sk] =
                    userConfig[k] and userConfig[k][sk] ~= nil and
                        userConfig[k][sk] or sv
            end
        else
            mergedConfig[k] = userConfig[k] ~= nil and userConfig[k] or v
        end
    end

    return mergedConfig
end

-- Save configuration to file
function config.save(config)
    local file = io.open("config.json", "w")
    if not file then
        print("Error: Could not open config.json for writing")
        return false
    end

    local success, jsonStr = pcall(function()
        return json.encode(config, {indent = true})
    end)

    if not success then
        print("Error encoding config to JSON:", jsonStr)
        file:close()
        return false
    end

    file:write(jsonStr)
    file:close()
    return true
end

return config
