-- script_loader.lua
-- Module for loading and managing scripts for the NT Lua Emulator
local M = {}

-- Required modules
local helpers = require("modules.helpers")
local display = require("modules.display")
local osc_client = require("modules.osc_client")
local debug_utils = require("modules.debug_utils")
local json = require("lib.dkjson")
local MinimalMode = require("modules.minimal_mode")

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

-- Helper function to extract directory from a file path
local function getDirectoryFromPath(filepath)
    local last_sep_pos
    -- Find the position *before* the last separator
    for i = #filepath, 1, -1 do
        local char = filepath:sub(i, i)
        if char == '/' or char == '\\' then
            last_sep_pos = i
            break
        end
    end

    if last_sep_pos then
        -- Return the substring up to and including the separator
        return filepath:sub(1, last_sep_pos)
    else
        -- No separator found, return empty string to represent the base directory
        return ""
    end
end

-- Load a script and initialize it
function M.loadScript(scriptPath, createDefaultMappings)
    -- Handle both absolute and relative paths
    local filePath = scriptPath
    local newScript
    local newScriptParameters = {} -- Initialize newScriptParameters here

    -- Save original package.path
    local original_package_path = package.path
    local success, result

    -- Use pcall to wrap the loading/initialization process to ensure path restoration
    -- Capture all results from pcall into a table
    local pcall_results = {
        pcall(function()
            -- Determine the script's directory using string manipulation
            local scriptDir = getDirectoryFromPath(filePath)
            local path_sep = package.config:sub(1, 1) -- Usually '/' or '\\'
            local list_sep = ";" -- Lua's path list separator

            -- Construct firmware-style paths relative to the script's directory
            -- No leading separator needed if scriptDir is already empty or ends with one
            local pattern1 = scriptDir .. "?"
            local pattern2 = scriptDir .. "?.lua"
            local pattern3 = scriptDir .. "lib" .. path_sep .. "?"
            local pattern4 = scriptDir .. "lib" .. path_sep .. "?.lua"
            local firmware_paths = table.concat({
                pattern1, pattern2, pattern3, pattern4
            }, list_sep)

            -- Prepend firmware paths to the current package.path
            package.path = firmware_paths .. list_sep .. original_package_path
            -- debug_utils.debugLog("Temporarily set package.path: " .. package.path) -- Optional debug

            -- Create the drawing environment FIRST - before any script code runs
            local drawingEnv = display.createDrawingEnvironment()

            -- Add drawing functions to the global environment before loading script
            for funcName, func in pairs(drawingEnv) do
                -- Make drawing functions available globally
                _G[funcName] = func
            end

            -- Add custom functions not provided by the display module

            -- Get voltage on a bus at an algorithm's input
            _G.getBusVoltage = function(algorithm, busIndex)
                -- In the emulator, we only have one algorithm, so we ignore the algorithm index
                -- busIndex is zero-based and ranges from 0 to 11 (for inputs 1-12)

                -- Validate bus index
                if busIndex < 0 or busIndex >= 12 then
                    return 0.0 -- Return 0V for invalid bus indices
                end

                -- Get the current input voltage from signal_processor
                local signalProcessor = require("modules.signal_processor")
                local currentInputs = signalProcessor.getCurrentInputs()
                return currentInputs[busIndex + 1] or 0.0 -- Convert zero-based to one-based index
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
                if newScript and paramIndex >= 1 and paramIndex <=
                    #newScriptParameters then
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

            -- Set a parameter value using normalized range [0.0,1.0]
            _G.setParameterNormalized = function(algorithm, parameter,
                                                 normalizedValue)
                -- Add debug logs here
                local debug_utils = require("modules.debug_utils")
                debug_utils.debugLog(string.format(
                                         "[_G.setParameterNormalized] alg: %d, param: %d, normalizedValue: %.4f",
                                         algorithm, parameter, normalizedValue))

                -- In the emulator, we only have one algorithm, so we ignore the algorithm index
                -- Adjust the parameter index based on parameterOffset
                local paramIndex = parameter -
                                       (newScript and newScript.parameterOffset or
                                           0)
                if newScript and paramIndex >= 1 and paramIndex <=
                    #newScriptParameters then
                    local sp = newScriptParameters[paramIndex]
                    if sp then
                        -- Map normalized value [0.0,1.0] to parameter range [min,max]
                        local value = sp.min +
                                          (normalizedValue * (sp.max - sp.min))
                        debug_utils.debugLog(string.format(
                                                 "[_G.setParameterNormalized] Mapped value before clamp/floor: %.4f (min: %.2f, max: %.2f, type: %s)",
                                                 value, sp.min, sp.max, sp.type))

                        -- Add specific handling for enum type
                        if sp.type == "enum" then
                            -- Map normalized value to the closest integer index
                            value = math.floor(value + 0.5) -- Round to nearest integer index
                            -- Ensure value is clamped within the valid index range [min, max]
                            value = math.max(sp.min, math.min(sp.max, value))
                            debug_utils.debugLog(string.format(
                                                     "[_G.setParameterNormalized] Enum value after rounding/clamping: %d",
                                                     value))
                        else
                            -- Ensure the value is within bounds for other types (integer, float)
                            if sp.type == "integer" then
                                value = math.floor(value)
                            end
                            value = math.max(sp.min, math.min(sp.max, value))
                        end

                        sp.current = value
                        debug_utils.debugLog(string.format(
                                                 "[_G.setParameterNormalized] Final value set: %.4f",
                                                 value))
                    else
                        debug_utils.debugLog(
                            "[_G.setParameterNormalized] Error: Script parameter object not found for index: " ..
                                paramIndex)
                    end
                else
                    debug_utils.debugLog(
                        "[_G.setParameterNormalized] Error: Calculated paramIndex out of bounds: " ..
                            paramIndex .. " (parameter: " .. parameter ..
                            ", offset: " ..
                            (newScript and newScript.parameterOffset or "nil") ..
                            ")")
                end
            end

            -- Find parameters by name within an algorithm
            _G.findParameter = function(algorithm, searchName)
                -- In the emulator, we only have one algorithm, so we ignore the algorithm index
                local results = {}

                -- If we don't have parameters yet, return empty results
                if not newScriptParameters then return results end

                -- Search through all parameters
                for i, param in ipairs(newScriptParameters) do
                    if param.name then
                        -- Check if the parameter name matches directly
                        if param.name == searchName then
                            table.insert(results, i +
                                             (newScript and
                                                 newScript.parameterOffset or 0))
                        else
                            -- Check if it's a prefixed parameter name (e.g., "1:Speed")
                            local prefix, baseName = param.name:match(
                                                         "^(%d+):(.+)$")
                            if baseName and baseName == searchName then
                                table.insert(results, i +
                                                 (newScript and
                                                     newScript.parameterOffset or
                                                     0))
                            end
                        end
                    end
                end

                return results
            end

            -- Standard pot turn functions (NOOPs for now)
            _G.standardPot1Turn = function(value)
                -- Standard behavior for the first potentiometer
                -- In the real device, this might control the currently focused parameter
                print("Pot 1 turned: " .. value)
            end

            _G.standardPot2Turn = function(value)
                -- Standard behavior for the second potentiometer
                -- In the real device, this might control the currently focused parameter
                print("Pot 2 turned: " .. value)
            end

            _G.standardPot3Turn = function(value)
                -- Standard behavior for the third potentiometer
                -- In the real device, this might control the currently focused parameter
                print("Pot 3 turned: " .. value)
            end

            local loadedScript -- Temporary variable to hold the script table

            -- Load script content based on path type
            if filePath:sub(1, 1) == "/" then
                -- For absolute paths, read the file directly
                local file = io.open(filePath, "r")
                if not file then
                    error("Error: Could not open script file: " .. filePath)
                end

                -- Protect the file reading operation
                local readStatus, content = pcall(function()
                    local content = file:read("*a")
                    file:close()
                    return content
                end)

                if not readStatus then
                    error("Error reading script file: " .. content)
                end

                -- Create a temporary chunk name for the script
                local chunkName = "@" .. filePath:match("([^/]+)%.lua$") or
                                      "unknown"

                -- Load the script content
                local chunk, err = load(content, chunkName, "t", _G) -- Load with global env
                if not chunk then
                    error("Error loading script: " .. err)
                end

                -- Execute the chunk to get the script table
                local execStatus, resultTable = pcall(chunk)
                if not execStatus then
                    error("Error executing script: " .. resultTable)
                end
                if not resultTable then
                    error("Error: Script returned nil: " .. filePath)
                end

                loadedScript = resultTable
                print("Successfully loaded script from (absolute):", filePath)
            else
                -- For relative paths, use require
                local requirePath = filePath:gsub("%.lua$", "")
                package.loaded[requirePath] = nil -- Ensure fresh load

                local requireStatus, resultTable = pcall(require, requirePath)
                if not requireStatus then
                    error("Error loading script via require: " .. resultTable)
                end
                if not resultTable then
                    error("Error: Script returned nil via require: " .. filePath)
                end

                loadedScript = resultTable
                print("Successfully loaded script from (relative):", filePath)
            end

            -- *** Assign loaded script to the outer scope variable ***
            newScript = loadedScript -- Now newScript is assigned

            -- Load overall emulator state from state.json (Should this be outside pcall?)
            -- Keeping it inside for now, as it interacts with script state.
            local emulatorState = {}
            local stateFile = io.open("state.json", "r")
            if stateFile then
                local readSuccess, content = pcall(function()
                    local content = stateFile:read("*a")
                    stateFile:close()
                    return content
                end)
                if readSuccess then
                    local decodeSuccess, decodedJson = pcall(json.decode,
                                                             content)
                    if decodeSuccess then
                        emulatorState = decodedJson
                        print("ScriptLoader: Successfully loaded state.json")
                    else
                        print("ScriptLoader: Error decoding state.json: ",
                              tostring(decodedJson))
                    end
                else
                    print("ScriptLoader: Error reading state.json: ",
                          tostring(content))
                    pcall(function()
                        if stateFile and not stateFile:isclosed() then
                            stateFile:close()
                        end
                    end)
                end
            else
                print(
                    "ScriptLoader: state.json not found or could not be opened.")
            end

            -- Assign saved script-specific state before calling init
            if emulatorState.scriptState and type(emulatorState.scriptState) ==
                "table" then
                newScript.state = emulatorState.scriptState
                print(
                    "ScriptLoader: Found scriptState, assigning to newScript.state")
            else
                newScript.state = nil
                print("ScriptLoader: No valid scriptState found.")
            end

            -- Call script's init function
            if newScript.init then
                local initResult = safeScriptCall(newScript.init, newScript) -- safeScriptCall handles pcall internally
                if initResult == nil then
                    -- safeScriptCall already printed error, maybe re-throw?
                    -- error("Error during script init function") -- Option to halt loading on init error
                    print("Warning: Error occurred during script init function.")
                elseif type(initResult) == "table" then
                    newScript.inputs = initResult.inputs or newScript.inputs
                    newScript.outputs = initResult.outputs or newScript.outputs
                    newScript.inputNames =
                        initResult.inputNames or newScript.inputNames
                    newScript.outputNames =
                        initResult.outputNames or newScript.outputNames
                    -- Copy MIDI configuration if present
                    newScript.midi = initResult.midi or newScript.midi
                    if initResult.parameters then
                        -- Parse parameters AFTER script object exists
                        newScriptParameters =
                            helpers.parseScriptParameters(initResult.parameters)
                        helpers.updateScriptParameters(newScriptParameters,
                                                       newScript)
                    end
                end
            end

            -- Add required fields to the script object (parameterOffset can be set here)
            newScript.parameterOffset = newScript.parameterOffset or 1 -- Use script-defined or default to 1

            -- Call setupUi if available
            if newScript.setupUi then
                local potPositions =
                    safeScriptCall(newScript.setupUi, newScript)
                if potPositions and type(potPositions) == "table" then
                    local controls = require("modules.controls")
                    controls.setPotPositions(potPositions)
                    debug_utils.debugLog(
                        "Set pot positions from script's setupUi")
                end
            end

            -- Return the script object and its parameters
            return newScript, newScriptParameters -- Return the potentially modified newScript and the generated parameters

        end)
    } -- End of the function passed to pcall, and end of table constructor

    -- Restore original package.path *immediately* after pcall finishes
    package.path = original_package_path
    -- debug_utils.debugLog("Restored package.path: " .. package.path) -- Optional debug

    -- Check pcall result from the table
    local success = pcall_results[1]
    if success then
        -- pcall succeeded, extract actual results
        local loadedScript = pcall_results[2] -- First value returned by inner function
        local scriptParams = pcall_results[3] -- Second value returned by inner function

        -- Ensure the script actually loaded
        if not loadedScript then
            showErrorNotification(
                "Failed to load script: Script object is nil after successful pcall.")
            print(
                "Error during script load/init process: Script object is nil after successful pcall.")
            return nil
        end

        -- Perform post-load actions OUTSIDE the pcall
        if osc_client then osc_client.setScript(loadedScript) end

        -- Set up generic control callbacks
        if loadedScript.button then
            for i = 1, 4 do
                if not loadedScript["button" .. i .. "Push"] then
                    loadedScript["button" .. i .. "Push"] = function()
                        safeScriptCall(loadedScript.button, loadedScript, i,
                                       true)
                    end
                end
                if not loadedScript["button" .. i .. "Release"] then
                    loadedScript["button" .. i .. "Release"] = function()
                        safeScriptCall(loadedScript.button, loadedScript, i,
                                       false)
                    end
                end
            end
        end

        -- Save the script path to state.json on success
        local emulatorState = {}
        pcall(function()
            local sf = io.open("state.json", "r");
            if sf then
                local c = sf:read("*a");
                sf:close();
                local dec, js = pcall(json.decode, c);
                if dec then emulatorState = js end
            end
        end)
        emulatorState.scriptPath = scriptPath
        pcall(function()
            local sf = io.open("state.json", "w");
            if sf then
                sf:write(json.encode(emulatorState, {indent = true}));
                sf:close()
            end
        end)

        return loadedScript, scriptParams
    else
        -- pcall failed
        local error_message = pcall_results[2] -- Error message is the second element
        showErrorNotification("Failed to load script: " ..
                                  tostring(error_message))
        print("Error during script load/init process:", tostring(error_message))
        return nil -- Return nil to indicate failure
    end
end

-- Serialise script state by calling the script's serialise function
function M.serialiseState(script)
    if not script then return nil end
    if not script.serialise or type(script.serialise) ~= "function" then
        return nil
    end

    -- Call the script's serialise function
    local status, state = pcall(script.serialise, script)
    if not status then
        if showErrorNotification then
            showErrorNotification("Error serialising script state: " ..
                                      tostring(state))
        end
        return nil
    end

    return state
end

-- Save script state to state.json
function M.saveScriptState(script)
    if not script then return false end

    -- Get script state through serialise function if it exists
    local scriptState = M.serialiseState(script)
    if not scriptState then return false end

    -- Load existing state.json
    local state = {}
    local stateFile = io.open("state.json", "r")
    if stateFile then
        -- Protect the file reading operation with pcall
        local readSuccess, content = pcall(function()
            local content = stateFile:read("*a")
            stateFile:close()
            return content
        end)

        if readSuccess then
            local success, result = pcall(json.decode, content)
            if success then state = result end
        else
            print("Error reading state file:", content) -- content will contain the error message
            -- Make sure the file is closed if there was an error
            pcall(function() if stateFile then stateFile:close() end end)
        end
    end

    -- Add script state to the state object
    state.scriptState = scriptState

    -- Write updated state back to file
    local stateFile = io.open("state.json", "w")
    if stateFile then
        -- Protect the file writing operation with pcall
        local writeSuccess, err = pcall(function()
            stateFile:write(json.encode(state, {indent = true}))
            stateFile:close()
            return true
        end)

        if writeSuccess then
            return true
        else
            print("Error writing state file:", err)
            -- Make sure the file is closed if there was an error
            pcall(function() if stateFile then stateFile:close() end end)
            return false
        end
    end

    return false
end

-- Check if a file has been modified
function M.checkScriptModified(path)
    local info

    if path:sub(1, 1) == "/" then
        -- For absolute paths, use lfs (LuaFileSystem) or fallback to io.open
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
            -- Fallback method using io.open with rate limiting
            local currentTime = love.timer.getTime()
            if currentTime - lastAbsolutePathCheckTime <
                absolutePathCheckInterval then
                -- Not enough time has passed since last check
                return false
            end

            -- Update last check time
            lastAbsolutePathCheckTime = currentTime

            -- Without LuaFileSystem, we'll check if we can open the file and read its contents
            local file = io.open(path, "r")
            if file then
                -- Protect the file reading operation with pcall
                local readSuccess, contents = pcall(function()
                    local contents = file:read("*a")
                    file:close()
                    return contents
                end)

                if not readSuccess then
                    print("Error reading file for modification check:", contents)
                    -- Make sure the file is closed if there was an error
                    pcall(function()
                        if file then file:close() end
                    end)
                    return false
                end

                -- Calculate a simple hash of the contents
                local hash = 0
                for i = 1, #contents do
                    hash = (hash * 31 + contents:byte(i)) % 2147483647
                end

                if hash ~= scriptLastModified then
                    scriptLastModified = hash
                    return true
                end
            end

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
                -- Without lfs, use content hashing
                local file = io.open(scriptPath, "r")
                if file then
                    local contents = file:read("*a")
                    file:close()

                    -- Calculate a simple hash of the contents
                    local hash = 0
                    for i = 1, #contents do
                        hash = (hash * 31 + contents:byte(i)) % 2147483647
                    end

                    scriptLastModified = hash
                end
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
