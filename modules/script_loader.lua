-- script_loader.lua
-- Module for loading and managing scripts for the NT Lua Emulator
local M = {}

-- Required modules
local helpers = require("helpers")
local display = require("display")
local osc_client = require("osc_client")
local debug_utils = require("debug_utils")
local json = require("lib.dkjson")
local MinimalMode = require("minimal_mode")

-- Local vars
local scriptLastModified = 0
local lastAbsolutePathCheckTime = 0
local absolutePathCheckInterval = 2.0 -- Check every 2 seconds

-- Function to show notifications (will be injected from emulator.lua)
local showNotification = nil
local showErrorNotification = nil

-- Function to safely call script functions with pcall
local function safeScriptCall(func, scriptObj, ...)
    if not func then return nil end

    local status, result = pcall(func, scriptObj, ...)
    if not status then
        showErrorNotification("Script error: " .. tostring(result))
        return nil
    end
    return result
end

-- Check if script has control callbacks and switch to controls tab if needed
local function hasControlCallbacks(script)
    return script.button ~= nil or script.pot1Turn ~= nil or script.pot2Turn ~=
               nil or script.pot3Turn ~= nil or script.pot1Push ~= nil or
               script.pot2Push ~= nil or script.pot3Push ~= nil or
               script.pot1Release ~= nil or script.pot2Release ~= nil or
               script.pot3Release ~= nil or script.encoder1Turn ~= nil or
               script.encoder2Turn ~= nil or script.encoder1Push ~= nil or
               script.encoder2Push ~= nil or script.encoder1Release ~= nil or
               script.encoder2Release ~= nil or script.button1Push ~= nil or
               script.button2Push ~= nil or script.button3Push ~= nil or
               script.button4Push ~= nil or script.button1Release ~= nil or
               script.button2Release ~= nil or script.button3Release ~= nil or
               script.button4Release ~= nil
end

-- Load a script and initialize it
function M.loadScript(scriptPath, createDefaultMappings)
    -- Handle both absolute and relative paths
    local filePath = scriptPath
    local newScript

    -- Create the drawing environment FIRST - before any script code runs
    local drawingEnv = display.createDrawingEnvironment()

    -- Add drawing functions to the global environment before loading script
    for funcName, func in pairs(drawingEnv) do
        -- Make drawing functions available globally
        _G[funcName] = func
    end

    -- Add custom drawing functions not provided by the display module

    -- Standard behavior for pot3 turning
    _G.standardPot3Turn = function(x)
        -- Standard behavior for the third potentiometer
        -- In the real device, this might scroll through parameters
        print("Pot 3 turned: " .. x)
    end

    -- Add exit function for compatibility
    _G.exit = function() love.event.quit() end

    -- Add compatibility functions for test scripts
    _G.getCurrentAlgorithm = function() return 0 end
    _G.getCurrentParameter = function() return 0 end

    -- Add debug function for scripts
    _G.debug = function(str) print(tostring(str)) end

    -- Screen coordinate conversion functions
    _G.toScreenX = function(x) return 1.0 + 2.5 * (x + 10.0) end

    _G.toScreenY = function(y)
        -- No need for special scaling here - the parameter system will handle
        -- the kBy10 scaling when setting/getting parameters
        return 12.0 + 2.5 * (10.0 - y)
    end

    -- Make parameterOffset available both as a function and a property
    _G.parameterOffset = 0

    -- Focus on a parameter (for pot/encoder interactions)
    _G.focusParameter = function(algorithm, parameter)
        -- In a real device, this would focus UI on a specific parameter
        -- For the emulator, we'll just log it
        debug_utils.debugLog("Focusing on parameter " .. parameter ..
                                 " of algorithm " .. algorithm)
        -- We could potentially store the current focused parameter for display
        -- but for now this is just a stub
    end

    -- Set a parameter value
    _G.setParameter = function(algorithm, parameter, value)
        -- In the emulator, we only have one algorithm, so we ignore the algorithm index
        -- Adjust the parameter index based on parameterOffset
        local paramIndex = parameter - newScript.parameterOffset
        if paramIndex >= 1 and paramIndex <= #newScriptParameters then
            local sp = newScriptParameters[paramIndex]
            if sp then
                -- Ensure the value is within bounds
                if sp.type == "integer" then
                    value = math.floor(value)
                end
                value = math.max(sp.min, math.min(sp.max, value))
                sp.current = value
            end
        end
    end

    if scriptPath:sub(1, 1) == "/" then
        -- For absolute paths, read the file directly
        local file = io.open(scriptPath, "r")
        if not file then
            print("Error: Could not open script file:", scriptPath)
            return nil
        end

        local content = file:read("*a")
        file:close()

        -- Create a temporary chunk name for the script
        local chunkName = "@" .. scriptPath:match("([^/]+)%.lua$")

        -- Load the script content
        local chunk, err = load(content, chunkName)
        if not chunk then
            print("Error loading script:", err)
            return nil
        end

        -- Execute the chunk to get the script table
        local status, result = pcall(chunk)
        if not status then
            print("Error executing script:", result)
            return nil
        end

        if not result then
            print("Error: Script returned nil:", scriptPath)
            return nil
        end

        newScript = result
        print("Successfully loaded script from:", scriptPath)
    else
        -- For relative paths, use require as before
        local requirePath = scriptPath:gsub("%.lua$", "")
        package.loaded[requirePath] = nil

        local status, result = pcall(require, requirePath)
        if not status then
            print("Error loading script:", result)
            return nil
        end

        if not result then
            print("Error: Script returned nil:", scriptPath)
            return nil
        end

        newScript = result
    end

    local newScriptParameters = {}

    if newScript.init then
        local initResult = safeScriptCall(newScript.init, newScript)
        if type(initResult) == "table" then
            -- Merge the I/O definitions and names returned from init into the script table
            newScript.inputs = initResult.inputs or newScript.inputs
            newScript.outputs = initResult.outputs or newScript.outputs
            newScript.inputNames = initResult.inputNames or newScript.inputNames
            newScript.outputNames = initResult.outputNames or
                                        newScript.outputNames

            if initResult.parameters then
                newScriptParameters = helpers.parseScriptParameters(
                                          initResult.parameters)
                helpers.updateScriptParameters(newScriptParameters, newScript)
            end
        end
    end

    -- Add required fields to the script object
    newScript.parameterOffset = 1 -- Add parameterOffset field with value 1

    -- Pass script to OSC client for output names
    if osc_client then osc_client.setScript(newScript) end

    -- Set up control callbacks
    if newScript.button then
        -- If the script has a button function, use it for all buttons
        for i = 1, 4 do
            newScript["button" .. i .. "Push"] = function()
                safeScriptCall(newScript.button, newScript, i, true)
            end
            newScript["button" .. i .. "Release"] = function()
                safeScriptCall(newScript.button, newScript, i, false)
            end
        end
    end

    -- Save the script path to state.json
    local state = {}
    local stateFile = io.open("state.json", "r")
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()
        local success, result = pcall(json.decode, content)
        if success then state = result end
    end
    state.scriptPath = scriptPath
    local stateFile = io.open("state.json", "w")
    if stateFile then
        stateFile:write(json.encode(state, {indent = true}))
        stateFile:close()
    end

    return newScript, newScriptParameters
end

-- Check if a file has been modified
function M.checkScriptModified(path)
    local info

    if path:sub(1, 1) == "/" then
        -- For absolute paths, use lfs (LuaFileSystem) or fallback to os.stat
        local success, lfs = pcall(require, "lfs")
        if success then
            info = lfs.attributes(path)
            if info and info.modification then
                local lastModified = info.modification
                if lastModified > scriptLastModified then
                    scriptLastModified = lastModified
                    return true
                end
                return false
            end
        else
            -- Fallback method using io with rate limiting
            local currentTime = love.timer.getTime()
            if currentTime - lastAbsolutePathCheckTime <
                absolutePathCheckInterval then
                -- Not enough time has passed since last check
                return false
            end

            -- Update last check time
            lastAbsolutePathCheckTime = currentTime

            -- Without LuaFileSystem, we can't reliably detect changes to absolute path files
            -- Instead, we'll only check once on startup (first time) and then require manual reload
            if scriptLastModified == 0 then
                -- First time checking this file - mark it as seen and don't reload
                scriptLastModified = 1 -- Use any non-zero value
                return false
            end

            -- For subsequent checks, never auto-reload
            return false
        end
    else
        -- For relative paths, use LÖVE's filesystem
        info = love.filesystem.getInfo(path)
        if not info then return false end

        local lastModified = info.modtime
        if lastModified > scriptLastModified then
            scriptLastModified = lastModified
            return true
        end

        return false
    end
end

-- Initialize the module with required notification functions
function M.init(notifyFunctions)
    showNotification = notifyFunctions.showNotification
    showErrorNotification = notifyFunctions.showErrorNotification

    -- Get initial modification time of the script if path provided
    if notifyFunctions.scriptPath then
        local scriptPath = notifyFunctions.scriptPath
        if scriptPath:sub(1, 1) == "/" then
            -- For absolute paths
            local success, lfs = pcall(require, "lfs")
            if success then
                local info = lfs.attributes(scriptPath)
                if info and info.modification then
                    scriptLastModified = info.modification
                end
            else
                -- Without lfs, set to 0 so the first check will set it to 1
                scriptLastModified = 0
            end
        else
            -- For relative paths, use LÖVE's filesystem
            local info = love.filesystem.getInfo(scriptPath)
            if info then scriptLastModified = info.modtime end
        end
    end
end

-- Export the module
return M
