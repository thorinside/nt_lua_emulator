-- emulator_script_host.lua
-- Handles script loading, reloading, and execution
local M = {} -- Module to return

-- Required modules
require("constants") -- For global constants
local helpers = require("helpers")
local display = require("display")
local osc_client = require("osc_client")
local json = require("lib.dkjson")
local debug_utils = require("debug_utils")

-- State
local scriptPath = "test_script.lua" -- Default path
local scriptLastModified = 0
local lastReloadTime = 0
local reloadBlink = false

-- Global variables for rate-limiting reload when using absolute paths
local lastAbsolutePathCheckTime = 0
local absolutePathCheckInterval = 2.0 -- Check every 2 seconds

-- Script state
local script = nil
local scriptParameters = {}
local scriptInputCount = 0
local scriptOutputCount = 0

-- Function to show error notifications - will be injected from emulator.lua
local showErrorNotification = function(message) print("Error: " .. message) end

-- Function to show normal notifications - will be injected from emulator.lua
local showNotification = function(message) print("Info: " .. message) end

-- SafeScriptCall for error handling
local function safeScriptCall(func, scriptObj, ...)
    if not func then return nil end

    local status, result = pcall(func, scriptObj, ...)
    if not status then
        showErrorNotification("Script error: " .. tostring(result))
        return nil
    end
    return result
end

-- Check if script has control callbacks
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

-- Create the drawing environment functions for scripts
local function setupDrawingEnvironment()
    -- Create the drawing environment
    local drawingEnv = display.createDrawingEnvironment()

    -- Add drawing functions to the global environment
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
end

-- Load a script and initialize it
local function loadScript(scriptPath)
    -- Handle both absolute and relative paths
    local filePath = scriptPath
    local newScript, newScriptParameters

    -- Set up the drawing environment FIRST - before any script code runs
    setupDrawingEnvironment()

    -- Set a parameter value - needs to be defined after newScript 
    -- is initialized so using a forward reference
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

    newScriptParameters = {}

    -- Initialize the script
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
local function checkScriptModified(path)
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

-- Public function to load a script from a path
function M.loadScriptFromPath(filePath, callbacks)
    if not filePath then return end

    print("Loading script from path:", filePath)

    -- Update scriptPath
    scriptPath = filePath

    -- Update state.json with the script path (don't update config.json)
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

    -- Load the new script
    local newScript, newScriptParameters = loadScript(scriptPath)

    if newScript then
        -- Update the script
        script = newScript
        scriptParameters = newScriptParameters

        -- Determine input/output counts from the updated script table
        if type(script.inputs) == "number" then
            scriptInputCount = script.inputs
        elseif type(script.inputs) == "table" then
            scriptInputCount = #script.inputs
        else
            scriptInputCount = 0
        end

        if type(script.outputs) == "number" then
            scriptOutputCount = script.outputs
        elseif type(script.outputs) == "table" then
            scriptOutputCount = #script.outputs
        else
            scriptOutputCount = 0
        end

        -- Call the success callback if provided
        if callbacks and callbacks.onScriptLoaded then
            callbacks.onScriptLoaded(script, scriptParameters, scriptInputCount,
                                     scriptOutputCount)
        end

        -- Show notification
        showNotification("Script loaded: " .. filePath:match("([^/]+)%.lua$"))
        return true
    else
        -- Show error notification
        showErrorNotification("Failed to load script: " .. filePath)

        -- Call the error callback if provided
        if callbacks and callbacks.onScriptLoadError then
            callbacks.onScriptLoadError(filePath)
        end

        return false
    end
end

-- Handle hot reloading check
function M.checkScriptHotReload(time, callbacks)
    -- Check for script file modification
    if checkScriptModified(scriptPath) then
        print("Script file changed, reloading...")

        -- Call pre-reload callback if provided
        if callbacks and callbacks.onBeforeReload then
            callbacks.onBeforeReload()
        end

        local newScript, newScriptParameters = loadScript(scriptPath)
        if newScript then
            -- Update the script
            script = newScript
            scriptParameters = newScriptParameters

            -- Determine input/output counts
            local prevInputCount = scriptInputCount
            local prevOutputCount = scriptOutputCount

            if type(script.inputs) == "number" then
                scriptInputCount = script.inputs
            elseif type(script.inputs) == "table" then
                scriptInputCount = #script.inputs
            else
                scriptInputCount = 0
            end

            if type(script.outputs) == "number" then
                scriptOutputCount = script.outputs
            elseif type(script.outputs) == "table" then
                scriptOutputCount = #script.outputs
            else
                scriptOutputCount = 0
            end

            -- Call the success callback if provided
            if callbacks and callbacks.onScriptReloaded then
                callbacks.onScriptReloaded(script, scriptParameters,
                                           scriptInputCount, scriptOutputCount,
                                           prevInputCount, prevOutputCount)
            end

            print("Script reloaded successfully!")

            -- Mark the reload blink state
            reloadBlink = true
            lastReloadTime = time
        else
            print("Error reloading script, continuing with previous version")

            -- Call the error callback if provided
            if callbacks and callbacks.onReloadError then
                callbacks.onReloadError()
            end
        end
        return true
    end

    -- Update reload blink state
    if reloadBlink and (time - lastReloadTime) > 1.0 then reloadBlink = false end

    return false
end

-- Set up notification functions
function M.setNotificationCallbacks(notifyFunc, errorFunc)
    showNotification = notifyFunc or showNotification
    showErrorNotification = errorFunc or showErrorNotification
end

-- Process script step
function M.processScriptStep(dt, scriptInputValues)
    if not script or not script.step then return nil end

    return safeScriptCall(script.step, script, dt, scriptInputValues)
end

-- Call a script function
function M.callScriptFunction(funcName, ...)
    if not script or not script[funcName] then return nil end

    return safeScriptCall(script[funcName], script, ...)
end

-- Getters for script state
function M.getScript() return script end

function M.getScriptParameters() return scriptParameters end

function M.getScriptInputCount() return scriptInputCount end

function M.getScriptOutputCount() return scriptOutputCount end

function M.getScriptPath() return scriptPath end

function M.isReloadBlinking() return reloadBlink end

function M.hasControlCallbacks() return hasControlCallbacks(script) end

-- Update script parameters
function M.updateScriptParameters()
    if script and scriptParameters then
        helpers.updateScriptParameters(scriptParameters, script)
    end
end

-- Initialize the module
function M.init(initialScriptPath)
    -- Set initial script path if provided
    if initialScriptPath then scriptPath = initialScriptPath end

    -- Try to load script path from state.json first
    local stateFile = io.open("state.json", "r")
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()
        local success, result = pcall(json.decode, content)
        if success and result.scriptPath then
            scriptPath = result.scriptPath
        end
    end

    return scriptPath
end

return M
