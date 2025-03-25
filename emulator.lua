-- emulator.lua
local M = {} -- We'll return this table.

-- Required modules
require("constants") -- These are global variables
-- Constants are now global: kGate, kTrigger, kCV, kBipolar, kUnipolar
local display = require("display")
local io_panel = require("io_panel")
local controls = require("controls")
local parameter_knobs = require("parameter_knobs")
local helpers = require("helpers")
local osc_client = require("osc_client")
local config = require("config")
local MinimalMode = require("minimal_mode") -- Add minimal mode module
local json = require("lib.dkjson") -- Add JSON library
local debug_utils = require("debug_utils")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local uiScaleFactor = 1.0 -- Base scale (rendering will be done at 4x)
local displayScaleFactor = 3.0 -- Adjusted to fit 256px display within 800px window width
local hiResRenderScale = 4.0 -- Factor for high-resolution rendering
local displayWidth, displayHeight = 256, 64

-- Calculate display area dimensions based on scale factors
local scaledDisplayWidth = displayWidth * displayScaleFactor
local scaledDisplayHeight = displayHeight * displayScaleFactor

-- Layout positions (starting after the display area)
local scriptIOPanelY = (scaledDisplayHeight / uiScaleFactor) + 20 -- Reduced top margin
local physicalIOStartY = scriptIOPanelY -- Removed extra space by aligning with script I/O
local paramKnobPanelY = physicalIOStartY + 300 -- Adjusted based on physical I/O height

local paramKnobRadius = 12
local paramKnobSpacing = 80

-- Script reloading configuration
local enableAutoReload = true
-- Use a default script path that will be overridden by state.json if available
local scriptPath = "test_script.lua" -- Default path
local scriptLastModified = 0
local lastReloadTime = 0
local reloadBlink = false

-- Global variables for rate-limiting reload when using absolute paths
local lastAbsolutePathCheckTime = 0
local absolutePathCheckInterval = 2.0 -- Check every 2 seconds

--------------------------------------------------------------------------------
-- Runtime State
--------------------------------------------------------------------------------
-- (Keep your state variables as is…)
local script
local time = 0

currentOutputs = {}
currentInputs = {}

local scriptInputCount = 0
local scriptOutputCount = 0
local scriptInputAssignments = {}
local scriptOutputAssignments = {}
-- We no longer need to maintain these global position arrays; they will be handled in io_panel.lua
-- local scriptInputPositions = {}
-- local scriptOutputPositions = {}

local inputClock = {}
for i = 1, 12 do inputClock[i] = false end
local inputPolarity = {}
for i = 1, 12 do inputPolarity[i] = kBipolar end -- bipolar by default
local inputScaling = {}
for i = 1, 12 do inputScaling[i] = 1.0 end -- default scaling factor (1.0 = no scaling)
local prevGateStates = {}

-- Add clock BPM configuration (default 110 BPM)
local clockBPM = 110
local baseBPM = 110 -- Base BPM for scaling calculations
local minBPM = 30 -- Minimum BPM
local maxBPM = 200 -- Maximum BPM

-- Trigger pulse visualization
local triggerPulseActive = {}
local triggerPulseTimes = {}
local triggerPulseDuration = 0.1 -- 100ms pulse duration

-- Dragging and parameter automation
local dragging = false
local dragType = nil
local dragIndex = nil
local dragX, dragY = 0, 0
local isDraggingInsideCircle = false
local scalingInput = nil
local scaleDragStartY = 0
local scaleDragSensitivity = 0.1

-- Parameter automation
local parameterAutomation = {} -- Maps parameter index to physical input index

local pendingPress = false
local pendingType = nil
local pendingIndex = nil
local pressX, pressY = 0, 0
local clickThreshold = 6

-- Double-click detection
local lastClickTime = 0
local lastClickType = nil
local lastClickIndex = nil
local doubleClickThreshold = 0.3 -- seconds

local scriptParameters = {}
local knobDragIndex = nil
local knobDragStartY = 0
local knobDragStartVal = 0
local knobDragSensitivity = 0.05

-- Pending single click actions (for when we need to wait for potential double-click)
local pendingClickActions = {}

local fontDefault, fontSmall

-- Add at the top with other state variables
local activeKnob = nil -- Currently hovered knob for mouse wheel control
local lastPhysicalIOBottomY = 0 -- Store the last known bottom Y position of physical I/O
local activeOverlay = "io" -- "controls" or "io"

-- Fade transition configuration
local fadeAlpha = 0.0
local fadeTarget = 1.0
local fadeSpeed = 2.0 -- Adjust this value for faster or slower fade

-- Local vars for caching window height calculations
local cachedIOHeight = nil

-- Global debug flag
local debugMode = false

-- IO State management
local stateFile = "state.json"
local mappingsChanged = false

-- Add notification system at top with other state variables
local errorNotification = {
    active = false,
    message = "",
    time = 0,
    duration = 5, -- Show error for 5 seconds
    alpha = 0,
    targetAlpha = 0
}

-- State for temporary notifications
local notification = {
    active = false,
    message = "",
    time = 0,
    duration = 2, -- seconds to show notification
    targetAlpha = 0.0,
    alpha = 0.0
}

-- Function to show notifications
local function showNotification(message)
    notification.active = true
    notification.message = message
    notification.time = 0
    notification.targetAlpha = 1.0
    print("Info: " .. message)
end

-- Function to show error notifications
local function showErrorNotification(message)
    errorNotification.active = true
    errorNotification.message = message
    errorNotification.time = 0
    errorNotification.targetAlpha = 1.0
    print("Error: " .. message)
end

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

-- Save current IO mappings to state.json
local function saveIOState()
    -- Only save if mappings have changed
    if not mappingsChanged then return end

    -- Get current window position and size (with safe checks)
    local wx, wy, ww, wh = 0, 0, 768, 600
    if love and love.window then
        if love.window.getPosition then
            wx, wy = love.window.getPosition()
        end
        if love.window.getWidth and love.window.getHeight then
            ww, wh = love.window.getWidth(), love.window.getHeight()
        end
    end

    local state = {
        scriptPath = scriptPath,
        inputs = {},
        outputs = {},
        inputModes = {}, -- Add storage for input modes
        oscEnabled = osc_client.isEnabled(), -- Save OSC enabled state
        window = {x = wx, y = wy, width = ww, height = wh},
        clockBPM = clockBPM -- Save global clock BPM setting
    }

    -- Convert input assignments to JSON-compatible format
    for i = 1, scriptInputCount do
        if scriptInputAssignments[i] then
            state.inputs[tostring(i)] = scriptInputAssignments[i]
        end
    end

    -- Convert output assignments to JSON-compatible format
    for i = 1, scriptOutputCount do
        if scriptOutputAssignments[i] then
            state.outputs[tostring(i)] = scriptOutputAssignments[i]
        end
    end

    -- Save input modes and scaling
    for i = 1, 12 do -- 12 physical inputs
        state.inputModes[tostring(i)] = {
            clock = inputClock[i] or false,
            polarity = inputPolarity[i] or kBipolar,
            scaling = inputScaling[i] or 1.0
        }
    end

    -- Convert to JSON
    local jsonData = json.encode(state, {indent = true})

    -- Save to file
    local file = io.open(stateFile, "w")
    if file then
        file:write(jsonData)
        file:close()
        print("IO mappings saved to " .. stateFile)
        mappingsChanged = false
    else
        print("Error: Could not save IO mappings to " .. stateFile)
    end
end

-- Load IO mappings from state.json
local function loadIOState()
    -- Check if state file exists
    local file = io.open(stateFile, "r")
    if not file then
        print("No saved state found at " .. stateFile)
        return false
    end

    -- Read the file
    local content = file:read("*all")
    file:close()

    -- Parse JSON
    local state = json.decode(content)
    if not state then
        print("Error parsing state file")
        return false
    end

    -- Check if state is for the current script
    if state.scriptPath ~= scriptPath then
        print("State is for a different script, not loading")
        return false
    end

    -- Apply input mappings
    if state.inputs then
        for scriptInput, physInput in pairs(state.inputs) do
            local idx = tonumber(scriptInput)
            if idx and idx <= scriptInputCount then
                scriptInputAssignments[idx] = physInput
            end
        end
    end

    -- Apply output mappings
    if state.outputs then
        for scriptOutput, physOutput in pairs(state.outputs) do
            local idx = tonumber(scriptOutput)
            if idx and idx <= scriptOutputCount then
                scriptOutputAssignments[idx] = physOutput
            end
        end
    end

    -- Apply input modes and scaling if present in the state
    if state.inputModes then
        for physInputStr, modeData in pairs(state.inputModes) do
            local idx = tonumber(physInputStr)
            if idx and idx >= 1 and idx <= 12 then
                if modeData.clock ~= nil then
                    inputClock[idx] = modeData.clock
                end
                if modeData.polarity ~= nil then
                    inputPolarity[idx] = modeData.polarity
                end
                if modeData.scaling ~= nil then
                    inputScaling[idx] = modeData.scaling
                end
            end
        end
        print("Input modes and scaling restored from state file")
    end

    -- Load the clock BPM if present
    if state.clockBPM then
        clockBPM = state.clockBPM
        print("Clock BPM restored: " .. clockBPM .. " BPM")
    end

    -- Restore window position and size if present
    if state.window then
        if state.window.x and state.window.y and state.window.width and
            state.window.height then
            if love and love.window then
                if love.window.setPosition then
                    love.window.setPosition(state.window.x, state.window.y)
                end
                if love.window.setMode then
                    love.window.setMode(state.window.width, state.window.height,
                                        {resizable = false, msaa = 8, vsync = 1})
                end
                print("Window position and size restored")
            end
        end
    end

    -- Restore OSC enabled state if present
    if state.oscEnabled ~= nil then
        local currentOscState = osc_client.isEnabled()
        if currentOscState ~= state.oscEnabled then
            -- Only toggle if the current state doesn't match the saved state
            osc_client.toggle()
            print("OSC state restored: " ..
                      (state.oscEnabled and "enabled" or "disabled"))
        end
    end

    print("IO mappings loaded from " .. stateFile)
    return true
end

-- Create default mappings (first n inputs, first m outputs)
local function createDefaultMappings()
    -- Map first n physical inputs to script inputs
    for i = 1, scriptInputCount do
        if i <= 12 then -- There are 12 physical inputs
            scriptInputAssignments[i] = i
        end
    end

    -- Map first m physical outputs to script outputs
    for i = 1, scriptOutputCount do
        if i <= 8 then -- There are 8 physical outputs
            scriptOutputAssignments[i] = i
        end
    end

    -- Mark as changed so it will be saved
    mappingsChanged = true
    print("Created default I/O mappings")
end

-- Mark that mappings have changed
local function markMappingsChanged() mappingsChanged = true end

--------------------------------------------------------------------------------
-- The Emulator Module Functions
--------------------------------------------------------------------------------
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

-- Helper function to calculate window height based on content and overlay type
local function calculateWindowHeight(overlay)
    -- Calculate the height of the display area in UI coordinates
    local displayAreaHeight = scaledDisplayHeight / uiScaleFactor

    -- Add 24px margin that will be at the bottom of the window
    local bottomMargin = 24

    if overlay == "controls" then
        -- For controls overlay - use the existing getHeight function
        return displayAreaHeight + controls.getHeight() + bottomMargin
    else
        -- For IO overlay - use cached height if available, or calculate it
        if cachedIOHeight then
            return displayAreaHeight + cachedIOHeight + bottomMargin
        end

        -- Define parameters for IO panel layout calculation
        local params = {
            script = script,
            inputCount = scriptInputCount or 0,
            outputCount = scriptOutputCount or 0,
            font = fontSmall,
            screenWidth = scaledDisplayWidth,
            ioY = (scaledDisplayHeight / uiScaleFactor) + 20
        }

        -- Get the height of the IO overlay components
        local scriptIOHeight = io_panel.getScriptIOHeight(params)
        local physicalIOHeight = io_panel.getPhysicalIOHeight()

        -- Calculate parameter knobs height
        local paramCount = scriptParameters and #scriptParameters or 0
        local paramKnobRows = math.ceil(paramCount / 9)
        local paramKnobHeight = 24 + (paramKnobRows * 24)

        -- Total content height
        local totalIOHeight = scriptIOHeight + physicalIOHeight +
                                  paramKnobHeight + 24 -- 24px spacing between sections

        -- Cache the calculated height
        cachedIOHeight = totalIOHeight

        return displayAreaHeight + totalIOHeight + bottomMargin
    end
end

-- Load a script and initialize it
local function loadScript(scriptPath)
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

    -- Provide drawing environment to script
    -- This section has been moved to the beginning of the function
    -- No longer need to set up the drawing environment here

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
                    -- Invalidate window height cache when script is modified
                    cachedIOHeight = nil
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
            -- Invalidate window height cache when script is modified
            cachedIOHeight = nil
            return true
        end

        return false
    end
end

-- Add a variable to track minimal mode state
local minimalModeEnabled = false

-- Initialize minimal mode
local MinimalMode = require("minimal_mode")
local minimalModeInitialized = false

-- At the end of the function M.load(), add:
function M.load()
    -- Calculate window size to fit the display and UI
    local windowWidth = scaledDisplayWidth -- Make window exactly as wide as the scaled display
    local windowHeight = calculateWindowHeight(activeOverlay) -- Use the shared calculation function

    -- Set window title
    love.window.setTitle("Disting NT LUA Emulator")

    -- Enable MSAA (multisample anti-aliasing) for smoother rendering
    love.window.setMode(windowWidth, windowHeight,
                        {resizable = false, msaa = 8, vsync = 1})

    -- Store initial window position
    local x, y = love.window.getPosition()
    love.window.setPosition(x, y)

    -- Set global line style for smoother lines
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("miter")

    -- Initialize display module
    display.init({
        width = displayWidth,
        height = displayHeight,
        scaling = displayScaleFactor, -- Use the full display scale factor
        baseColor = {0, 1, 1} -- Teal base color for display
    })

    -- Higher quality fonts for better legibility
    fontDefault = love.graphics.newFont(14) -- Default font at original size
    fontSmall = love.graphics.newFont(12) -- Small font at original size

    -- Get initial modification time
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

    -- Initialize OSC client first
    osc_client.init()

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

    -- Load the script
    script, scriptParameters = loadScript(scriptPath)

    if not script then
        print("Failed to load script:", scriptPath)
        return
    end

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

    -- Clear existing assignments
    for i = 1, scriptInputCount do scriptInputAssignments[i] = nil end
    for i = 1, scriptOutputCount do scriptOutputAssignments[i] = nil end

    -- Create default mappings first
    createDefaultMappings()

    -- Then try to load saved state, which will override defaults if it exists
    if loadIOState() then
        print("Loaded I/O mappings from state.json")
    else
        print("No saved state found, using default mappings")
        -- Save the default mappings to state.json
        saveIOState()
    end

    -- Initialize minimal mode with display module
    if not minimalModeInitialized then
        MinimalMode.init(display, scriptParameters,
                         function(paramIndex, newValue)
            -- Update the parameter in scriptParameters
            if scriptParameters and scriptParameters[paramIndex] then
                local param = scriptParameters[paramIndex]
                param.current = newValue
                -- Update the script's parameters using the helper module
                helpers.updateScriptParameters(scriptParameters, script)
            end
        end)
        minimalModeInitialized = true
    end

    -- Set initial minimal mode state from state.json if available
    minimalModeEnabled = false -- Default value
    local stateFile = io.open("state.json", "r")
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()
        local success, result = pcall(json.decode, content)
        if success and result.minimalMode ~= nil then
            minimalModeEnabled = result.minimalMode
        end
    end

    -- Calculate correct window size based on minimal mode
    windowHeight = calculateWindowHeight(activeOverlay)
    love.window.setMode(windowWidth, windowHeight,
                        {resizable = false, msaa = 8, vsync = 1})
end

-- Modify the update function to support minimal mode
function M.update(dt)
    -- Update fade transition
    if fadeAlpha ~= fadeTarget then
        fadeAlpha = fadeAlpha + (fadeTarget - fadeAlpha) * fadeSpeed * dt
        -- Stop when very close to target
        if math.abs(fadeAlpha - fadeTarget) < 0.01 then
            fadeAlpha = fadeTarget
        end
    end

    -- Update controls active state based on current overlay and minimal mode
    controls.setActive(activeOverlay == "controls" and not minimalModeEnabled)

    -- If in minimal mode, update it
    if minimalModeEnabled then
        -- Update parameter references in minimal mode
        MinimalMode.setParameters(scriptParameters)
        MinimalMode.update(dt)
    end

    -- Only proceed with update if we have a valid script
    if not script then return end

    -- Add debug information for tracking gate signals
    if debugMode then
        -- Log gate states for troubleshooting
        local gateLog = "Gate states: "
        for i = 1, 12 do
            if prevGateStates[i] then
                gateLog = gateLog ..
                              string.format("[%d]=%.2fV ", i, prevGateStates[i])
            end
        end
        if string.len(gateLog) > 13 then debug_utils.debugLog(gateLog) end
    end

    -- Script reload checks are the same...

    -- Modify the draw function to support minimal mode

    -- Script reload checks are the same...

    -- Check for script file modification
    if checkScriptModified(scriptPath) then
        print("Script file changed, reloading...")

        -- Save current IO mappings before reload
        saveIOState()

        -- Invalidate window height cache when script is reloaded
        cachedIOHeight = nil

        local newScript, newScriptParameters = loadScript(scriptPath)
        if newScript then
            -- Store previous I/O connections
            local prevInputAssignments = scriptInputAssignments
            local prevOutputAssignments = scriptOutputAssignments

            -- Update the script
            script = newScript
            scriptParameters = newScriptParameters

            -- Reset and update control callbacks in case script has changed
            local controlCallbacks = {
                onButtonPress = function(buttonIndex)
                    if script then
                        local functionName = "button" .. buttonIndex .. "Push"
                        if script[functionName] then
                            print("Button " .. buttonIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        elseif script.button then
                            print("Button " .. buttonIndex ..
                                      " pressed, calling script.button")
                            safeScriptCall(script.button, script, buttonIndex,
                                           true)
                        end
                    end
                end,
                onButtonRelease = function(buttonIndex)
                    if script then
                        local functionName =
                            "button" .. buttonIndex .. "Release"
                        if script[functionName] then
                            print("Button " .. buttonIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        elseif script.button then
                            print("Button " .. buttonIndex ..
                                      " released, calling script.button")
                            safeScriptCall(script.button, script, buttonIndex,
                                           false)
                        end
                    end
                end,
                onPotChange = function(potIndex, value)
                    if script then
                        local functionName = "pot" .. potIndex .. "Turn"
                        if script[functionName] then
                            print(
                                "Pot " .. potIndex .. " changed to " .. value ..
                                    ", calling script." .. functionName)
                            safeScriptCall(script[functionName], script, value)
                        elseif script.pot then
                            print(
                                "Pot " .. potIndex .. " changed to " .. value ..
                                    ", calling script.pot")
                            safeScriptCall(script.pot, script, potIndex, value)
                        end
                    end
                end,
                onPotPress = function(potIndex)
                    if script then
                        local functionName = "pot" .. potIndex .. "Push"
                        if script[functionName] then
                            print("Pot " .. potIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onPotRelease = function(potIndex)
                    if script then
                        local functionName = "pot" .. potIndex .. "Release"
                        if script[functionName] then
                            print("Pot " .. potIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onEncoderChange = function(encoderIndex, delta)
                    if script then
                        local functionName = "encoder" .. encoderIndex .. "Turn"
                        if script[functionName] then
                            print(
                                "Encoder " .. encoderIndex .. " changed by " ..
                                    delta .. ", calling script." .. functionName)
                            safeScriptCall(script[functionName], script, delta)
                        elseif script.encoder then
                            print(
                                "Encoder " .. encoderIndex .. " changed by " ..
                                    delta .. ", calling script.encoder")
                            safeScriptCall(script.encoder, script, encoderIndex,
                                           delta)
                        end
                    end
                end,
                onEncoderPress = function(encoderIndex)
                    if script then
                        local functionName = "encoder" .. encoderIndex .. "Push"
                        if script[functionName] then
                            print("Encoder " .. encoderIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onEncoderRelease = function(encoderIndex)
                    if script then
                        local functionName =
                            "encoder" .. encoderIndex .. "Release"
                        if script[functionName] then
                            print("Encoder " .. encoderIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end
            }
            controls.setCallbacks(controlCallbacks)

            -- Set active overlay based on script callbacks
            if hasControlCallbacks(script) then
                activeOverlay = "controls"

                -- Update window height to match if changed
                local wx, wy = love.window.getPosition()
                love.window.setMode(scaledDisplayWidth,
                                    calculateWindowHeight(activeOverlay),
                                    {resizable = false, msaa = 8, vsync = 1})
                love.window.setPosition(wx, wy)
            end

            -- Recalculate I/O counts
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

            -- Restore previous I/O connections where possible
            scriptInputAssignments = {}
            scriptOutputAssignments = {}

            for i = 1, scriptInputCount do
                scriptInputAssignments[i] = prevInputAssignments[i]
            end

            for i = 1, scriptOutputCount do
                scriptOutputAssignments[i] = prevOutputAssignments[i]
            end

            -- Reset outputs that are no longer connected after reload
            for i = 1, 8 do -- 8 physical outputs
                local stillConnected = false
                for _, physOutput in pairs(scriptOutputAssignments) do
                    if physOutput == i then
                        stillConnected = true
                        break
                    end
                end
                if not stillConnected then currentOutputs[i] = 0 end
            end

            print("Script reloaded successfully!")

            -- Mark the reload blink state
            reloadBlink = true
            lastReloadTime = time
        else
            print("Error reloading script, continuing with previous version")
        end
        return
    end

    -- Update reload blink state
    if reloadBlink and (time - lastReloadTime) > 1.0 then reloadBlink = false end

    time = time + dt

    -- Update display module
    display.update(dt)

    -- Process any pending click actions
    local currentTime = love.timer.getTime()
    local i = 1
    while i <= #pendingClickActions do
        local action = pendingClickActions[i]

        if currentTime >= action.executeAfter then
            -- Time to execute this action
            if action.type == "cycleInputMode" then
                local inputIdx = action.inputIndex

                -- Execute the mode cycling logic
                if inputPolarity[inputIdx] == kBipolar and
                    not inputClock[inputIdx] then
                    -- From bipolar -> clock mode
                    inputClock[inputIdx] = true
                    markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to clock mode (delayed action)")
                elseif inputClock[inputIdx] then
                    -- From clock -> unipolar mode
                    inputClock[inputIdx] = false
                    inputPolarity[inputIdx] = kUnipolar
                    markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to unipolar mode (0V to +10V) (delayed action)")
                else
                    -- From unipolar -> bipolar (default)
                    inputPolarity[inputIdx] = kBipolar
                    inputClock[inputIdx] = false
                    markMappingsChanged() -- Mark as changed when mode changes
                    print("Input " .. inputIdx ..
                              " set to bipolar mode (-5V to +5V) (delayed action)")
                end
            end

            -- Remove this action
            table.remove(pendingClickActions, i)
        else
            -- Skip to next action
            i = i + 1
        end
    end

    -- Simulate 12 physical inputs
    local period = 60 / clockBPM
    local halfPeriod = period / 2

    -- Update trigger pulse states
    for i = 1, 12 do
        if triggerPulseActive[i] then
            local pulseElapsed = time - (triggerPulseTimes[i] or 0)
            if pulseElapsed > triggerPulseDuration then
                triggerPulseActive[i] = false
            end
        end
    end

    -- Determine which physical inputs are connected to script inputs and their types
    local physInputToScriptType = {}
    if type(script.inputs) == "table" then
        for scriptInputIdx, assignedPhysInput in pairs(scriptInputAssignments) do
            if assignedPhysInput and script.inputs[scriptInputIdx] then
                physInputToScriptType[assignedPhysInput] =
                    script.inputs[scriptInputIdx]
            end
        end
    end

    for i = 1, 12 do
        local inputType = physInputToScriptType[i]
        local scale = inputScaling[i] or 1.0

        if inputClock[i] then
            -- Clock mode - generate gate signals based on BPM
            local phase = time % period
            local baseValue = (phase < halfPeriod) and 5 or 0
            -- Apply scaling to the base value
            currentInputs[i] = baseValue * scale

            -- Process gate inputs by checking which script inputs this physical input is assigned to
            for scriptInputIdx, assignedPhysInput in pairs(
                                                         scriptInputAssignments) do
                if assignedPhysInput == i then
                    -- Found an assignment, check if it's a kGate
                    if type(script.inputs) == "table" and
                        script.inputs[scriptInputIdx] == kGate and script.gate then
                        local prev = prevGateStates[i] or currentInputs[i]
                        if prev ~= currentInputs[i] then
                            local rising = (currentInputs[i] > prev)
                            if debugMode then
                                debug_utils.debugLog(string.format(
                                                         "GATE CHANGE: [%d] %.2fV -> %.2fV (rising=%s)",
                                                         i, prev,
                                                         currentInputs[i],
                                                         rising and "true" or
                                                             "false"))
                            end
                            safeScriptCall(script.gate, script, scriptInputIdx,
                                           rising)
                        end
                    end
                end
            end

            prevGateStates[i] = currentInputs[i]
        elseif inputType == kTrigger then
            -- Trigger input - show pulse when active
            if triggerPulseActive[i] then
                currentInputs[i] = 10.0 * scale -- High voltage during pulse, scaled
            else
                currentInputs[i] = 0.0 -- Zero when inactive
            end
        else
            -- CV mode - generate continuous values with sine waves
            local baseValue = math.sin(time + i)

            if inputPolarity[i] == kBipolar then
                -- Bipolar mode: -5V to +5V
                currentInputs[i] = 5 * scale * baseValue
                -- Clamp to valid range
                currentInputs[i] = math.max(-5, math.min(5, currentInputs[i]))
            else
                -- Unipolar mode: 0V to +10V
                -- First scale the base value, then shift to unipolar range
                currentInputs[i] = 5 + (5 * scale * baseValue)
                -- Clamp to valid range
                currentInputs[i] = math.max(0, math.min(10, currentInputs[i]))
            end
        end
    end

    -- Create inputs table to pass to script.step
    local scriptInputValues = {}

    -- For each script input, look for an assigned physical input and get its value
    for i = 1, scriptInputCount do
        local physicalInput = scriptInputAssignments[i]
        if physicalInput then
            scriptInputValues[i] = currentInputs[physicalInput]
        else
            scriptInputValues[i] = 0 -- Default value if no physical input is assigned
        end
    end

    -- Reset all physical outputs that aren't connected to any script output
    local connectedOutputs = {}
    for _, physOutput in pairs(scriptOutputAssignments) do
        connectedOutputs[physOutput] = true
    end

    -- Reset any output not in the connected list to 0V
    for i = 1, 8 do -- 8 physical outputs
        if not connectedOutputs[i] then currentOutputs[i] = 0 end
    end

    -- Call the script's step function to update outputs
    local outs
    if script and script.step then
        outs = safeScriptCall(script.step, script, dt, scriptInputValues)
    end

    -- Route each script output to the appropriate physical output if a new value is provided.
    if type(outs) == "table" then
        for slot, value in ipairs(outs) do
            if value ~= nil then
                -- Debug negative values specifically to find -5V
                if debugMode and value < 0 then
                    debug_utils.debugLog(string.format(
                                             "[DEBUG] Negative output detected: [%d] = %.6f",
                                             slot, value))
                end

                local mappedOutput = scriptOutputAssignments[slot]
                if mappedOutput then
                    currentOutputs[mappedOutput] = value
                else
                    -- Default to the same-numbered physical output if available.
                    if slot <= 8 then
                        currentOutputs[slot] = value
                    end
                end
            end
        end
    end

    -- Send outputs via OSC
    if scriptOutputCount > 0 then
        local oscOutputs = {}
        for i = 1, scriptOutputCount do
            local mappedOutput = scriptOutputAssignments[i]
            if mappedOutput then
                oscOutputs[i] = currentOutputs[mappedOutput]
            else
                oscOutputs[i] = 0
            end
        end
        osc_client.sendOutputs(oscOutputs)
    end

    -- Update automated parameters from input values
    for paramIndex, inputIndex in pairs(parameterAutomation) do
        local sp = scriptParameters[paramIndex]
        local inputValue = currentInputs[inputIndex] or 0

        -- Store base value if not already stored when connecting the parameter
        if sp and not sp.baseValue then sp.baseValue = sp.current end

        if sp and (sp.type == "integer" or sp.type == "float") then
            -- First normalize the CV input to 0-1 range
            local normalizedCV
            if inputPolarity[inputIndex] == kBipolar then
                -- Convert -5V to +5V range to -0.5 to +0.5 range
                normalizedCV = inputValue / 10.0 -- -0.5 to +0.5
            else
                -- Convert 0V to +10V range to 0 to 1 range
                normalizedCV = inputValue / 10.0 -- 0 to 1
            end

            -- Calculate parameter range (using unscaled values)
            local paramRange = sp.max - sp.min

            -- Apply the normalized CV to the parameter range
            local offset = normalizedCV * paramRange

            -- Add offset to base value
            local newValue = sp.baseValue + offset

            -- For integer parameters, round to nearest whole number
            if sp.type == "integer" then
                newValue = math.floor(newValue + 0.5)
            end

            -- Ensure value is within bounds (using unscaled values)
            sp.current = math.max(sp.min, math.min(sp.max, newValue))

        elseif sp and sp.type == "enum" then
            -- For enum parameters, normalize CV to control enum indices
            local valueCount = #sp.values

            -- First normalize the CV input
            local normalizedCV
            if inputPolarity[inputIndex] == kBipolar then
                -- Convert -5V to +5V range to -0.5 to +0.5 range
                normalizedCV = inputValue / 10.0 -- -0.5 to +0.5
            else
                -- Convert 0V to +10V range to 0 to 1 range
                normalizedCV = inputValue / 10.0 -- 0 to 1
            end

            -- Scale normalized CV to enum range and add to base index
            local offset = math.floor(normalizedCV * valueCount + 0.5)
            local valueIndex = sp.baseValue + offset

            -- Ensure the index is valid
            valueIndex = math.max(1, math.min(valueCount, valueIndex))
            sp.current = valueIndex
        end
    end

    -- Update script.parameters using the helper module
    if scriptParameters then
        helpers.updateScriptParameters(scriptParameters, script)
    end
end

-- Modify the draw function to support minimal mode
function M.draw()
    -- Reset line width for consistent drawing
    love.graphics.setLineWidth(1.0)
    -- Reset color to white at the beginning to ensure a clean state
    love.graphics.setColor(1, 1, 1, 1)

    -- 1) Set up the display canvas for script drawing
    display.clear()

    -- Start drawing to display's canvas with clean state
    love.graphics.push("all")
    love.graphics.setCanvas(display.getConfig().canvas)
    love.graphics.clear(0, 0, 0, 1) -- Ensure canvas is completely cleared

    -- Draw script content to display canvas with error handling
    if script and script.draw then
        local success, err = pcall(function() script.draw(script) end)

        if not success then
            print("ERROR in script draw: " .. tostring(err))
            MinimalMode.setError(err)
        end
    end

    -- Reset canvas state
    love.graphics.setCanvas()
    love.graphics.pop()

    -- Reset color to white after canvas operations
    love.graphics.setColor(1, 1, 1, 1)

    -- If in minimal mode, use minimal mode drawing
    if minimalModeEnabled then
        -- Use minimal mode display
        love.graphics.clear(0, 0, 0)
        -- Make sure color is white before rendering the display
        love.graphics.setColor(1, 1, 1, 1)
        display.render()

        -- Call minimal mode's draw function
        MinimalMode.draw()
    else
        -- Normal rendering with all UI elements

        -- Make sure color is white before rendering the display
        love.graphics.setColor(1, 1, 1, 1)
        display.render()

        -- Draw a border around the display area for better visualization
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8) -- Light gray, semi-transparent
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 0, 0, scaledDisplayWidth,
                                scaledDisplayHeight)

        -- Draw the active overlay
        if activeOverlay == "controls" then
            -- Draw the controls section below the display
            controls.layout(0, 0, scaledDisplayWidth, scaledDisplayHeight)
            controls.draw()
        else
            -- Draw Script I/O panel (inputs & outputs)
            local scriptIOPanelY = (scaledDisplayHeight / uiScaleFactor) + 20
            local physicalIOStartY = scriptIOPanelY
            io_panel.drawScriptIO({
                script = script,
                font = fontSmall,
                inputCount = scriptInputCount,
                outputCount = scriptOutputCount,
                inputAssignments = scriptInputAssignments,
                outputAssignments = scriptOutputAssignments,
                ioY = scriptIOPanelY,
                cellH = 40
            })

            -- Draw Physical I/O grids
            local physicalIOBottomY = io_panel.drawPhysicalIO({
                currentInputs = currentInputs,
                currentOutputs = currentOutputs,
                inputClock = inputClock,
                inputPolarity = inputPolarity,
                inputScaling = inputScaling,
                clockBPM = clockBPM,
                font = fontDefault,
                physInputX = 40,
                physInputY = physicalIOStartY,
                cellW = 40,
                cellH = 40
            })

            -- Store the bottom Y position for use in other functions
            lastPhysicalIOBottomY = physicalIOBottomY

            -- Display BPM if there's at least one clock input
            local hasClockInput = false
            for i = 1, 12 do
                if inputClock[i] then
                    hasClockInput = true
                    break
                end
            end

            if hasClockInput then
                -- Center BPM text specifically under the bottom row of inputs (9-12)
                love.graphics.setColor(1, 1, 1, 0.5) -- 50% opacity
                local bpmText = string.format("BPM %.0f", clockBPM)
                local smallFont = love.graphics.newFont(10) -- Smaller font
                local prevFont = love.graphics.getFont()
                love.graphics.setFont(smallFont)
                local textWidth = smallFont:getWidth(bpmText)

                -- Get positions of inputs 9-12 (bottom row)
                local inputPos = io_panel.getPhysicalInputPositions()
                if inputPos and #inputPos >= 12 then
                    -- Calculate center between input 9 and input 12
                    local leftX = inputPos[9][1]
                    local rightX = inputPos[12][1]
                    local centerX = (leftX + rightX) / 2 - textWidth / 2

                    -- Calculate Y position with 16px gap under bottom row
                    local bottomY = inputPos[9][2] + 15 -- Radius of input circle
                    local textY = bottomY + 16 -- 16px gap below the bottom of the circles

                    love.graphics.print(bpmText, centerX, textY)
                else
                    -- Fallback if positions not available
                    local cellWidth = 40 -- Width of each input cell
                    local inputSectionWidth = 4 * cellWidth
                    local inputCenterX = 40 + (inputSectionWidth / 2) -- 40 is physInputX
                    local centerX = inputCenterX - textWidth / 2
                    love.graphics
                        .print(bpmText, centerX, physicalIOBottomY + 16)
                end

                love.graphics.setFont(prevFont) -- Restore previous font
            end

            -- Draw Parameter Knobs using the new layout (9 per row)
            parameter_knobs.draw({
                scriptParameters = scriptParameters,
                displayWidth = displayWidth,
                panelY = physicalIOBottomY + 24, -- Position 24px below physical I/O section
                knobRadius = paramKnobRadius,
                knobSpacing = paramKnobSpacing,
                parameterAutomation = parameterAutomation
            })
        end

        -- Draw dragging line if needed (using positions from io_panel)
        if dragging then
            love.graphics.setColor(1, 1, 0)
            local srcX, srcY = 0, 0
            if dragType == "input" then
                local pos = io_panel.getInputPosition(dragIndex)
                if pos then srcX, srcY = pos[1], pos[2] end
            elseif dragType == "output" then
                local pos = io_panel.getOutputPosition(dragIndex)
                if pos then srcX, srcY = pos[1], pos[2] end
            end
            love.graphics.line(srcX, srcY, dragX, dragY)
        end

        -- Draw hot reload indicator LED directly on screen
        if enableAutoReload then
            if reloadBlink and math.floor(time * 4) % 2 == 0 then
                -- Blink yellow fast when recently reloaded
                love.graphics.setColor(1, 1, 0, 0.8)
            else
                -- Steady green when enabled
                love.graphics.setColor(0, 1, 0, 0.8)
            end
        else
            -- Gray when disabled
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        end

        -- Draw hot reload LED at bottom right of screen
        love.graphics.circle("fill", love.graphics.getWidth() - 16,
                             love.graphics.getHeight() - 6, 3)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("line", love.graphics.getWidth() - 16,
                             love.graphics.getHeight() - 6, 3)

        -- Draw OSC indicator LED
        if osc_client.isEnabled() then
            -- Green when enabled
            love.graphics.setColor(0, 1, 0, 0.8)
        else
            -- Gray when disabled
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        end

        -- Draw OSC LED at bottom right of screen (to the right of hot reload LED)
        love.graphics.circle("fill", love.graphics.getWidth() - 6,
                             love.graphics.getHeight() - 6, 3)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("line", love.graphics.getWidth() - 6,
                             love.graphics.getHeight() - 6, 3)

        -- Draw error notification if active
        if errorNotification.active then
            -- Update notification alpha for fade in/out
            errorNotification.alpha = errorNotification.alpha +
                                          (errorNotification.targetAlpha -
                                              errorNotification.alpha) * 0.01 *
                                          5

            -- Background rectangle
            love.graphics.setColor(0.1, 0.1, 0.1, errorNotification.alpha * 0.9)
            local notifWidth = 400
            local notifHeight = 80
            local notifX = (love.graphics.getWidth() - notifWidth) / 2
            local notifY = 100
            love.graphics.rectangle("fill", notifX, notifY, notifWidth,
                                    notifHeight, 8, 8)

            -- Border
            love.graphics.setColor(0.9, 0.2, 0.2, errorNotification.alpha * 0.9)
            love.graphics.rectangle("line", notifX, notifY, notifWidth,
                                    notifHeight, 8, 8)

            -- Text
            love.graphics.setColor(1, 1, 1, errorNotification.alpha)
            love.graphics.setFont(fontDefault)
            love.graphics.printf("Error", notifX + 10, notifY + 10,
                                 notifWidth - 20, "center")
            love.graphics.setFont(fontSmall)
            love.graphics.printf(errorNotification.message, notifX + 10,
                                 notifY + 35, notifWidth - 20, "center")

            -- Update notification time
            errorNotification.time = errorNotification.time + 0.01
            if errorNotification.time > errorNotification.duration then
                errorNotification.targetAlpha = 0
                if errorNotification.alpha < 0.01 then
                    errorNotification.active = false
                end
            end
        end

        -- Draw regular notification if active
        if notification.active then
            -- Update notification alpha for fade in/out
            notification.alpha = notification.alpha +
                                     (notification.targetAlpha -
                                         notification.alpha) * 0.01 * 5

            -- Background rectangle
            love.graphics.setColor(0.1, 0.1, 0.1, notification.alpha * 0.9)
            local notifWidth = 400
            local notifHeight = 60
            local notifX = (love.graphics.getWidth() - notifWidth) / 2
            local notifY = 100
            love.graphics.rectangle("fill", notifX, notifY, notifWidth,
                                    notifHeight, 8, 8)

            -- Border
            love.graphics.setColor(0.3, 0.7, 0.9, notification.alpha * 0.9)
            love.graphics.rectangle("line", notifX, notifY, notifWidth,
                                    notifHeight, 8, 8)

            -- Text
            love.graphics.setColor(1, 1, 1, notification.alpha)
            love.graphics.setFont(fontDefault)
            love.graphics.printf(notification.message, notifX + 10, notifY + 20,
                                 notifWidth - 20, "center")

            -- Update notification time
            notification.time = notification.time + 0.01
            if notification.time > notification.duration then
                notification.targetAlpha = 0
                if notification.alpha < 0.01 then
                    notification.active = false
                end
            end
        end
    end
end

-- Modify the keypressed function to add F1 toggle
function M.keypressed(key)
    -- F1 toggles minimal mode
    if key == "f1" then
        minimalModeEnabled = not minimalModeEnabled

        if minimalModeEnabled then
            MinimalMode.activate()
            -- Save window position
            local x, y = love.window.getPosition()

            -- Set window to display size only
            local config = display.getConfig()
            love.window.setMode(config.width * config.scaling,
                                config.height * config.scaling,
                                {resizable = false, msaa = 8, vsync = 1})

            -- Restore position
            love.window.setPosition(x, y)
        else
            MinimalMode.deactivate()

            -- Save window position
            local x, y = love.window.getPosition()

            -- Restore normal window size
            local windowWidth = scaledDisplayWidth
            local windowHeight = calculateWindowHeight(activeOverlay)
            love.window.setMode(windowWidth, windowHeight,
                                {resizable = false, msaa = 8, vsync = 1})

            -- Restore position
            love.window.setPosition(x, y)
        end

        -- Save minimalModeEnabled to state.json instead of config
        local state = {}
        local stateFile = io.open("state.json", "r")
        if stateFile then
            local content = stateFile:read("*a")
            stateFile:close()
            local success, result = pcall(json.decode, content)
            if success then state = result end
        end
        state.minimalMode = minimalModeEnabled
        local stateFile = io.open("state.json", "w")
        if stateFile then
            stateFile:write(json.encode(state, {indent = true}))
            stateFile:close()
        end

        return
    end

    -- Handle key in minimal mode if active
    if minimalModeEnabled then
        if MinimalMode.keypressed(key) then
            return -- Key was handled by minimal mode
        end
    end

    -- Continue with normal key handling
    if key == "space" then
        -- Only toggle overlays when not in minimal mode
        if not minimalModeEnabled then
            -- Simple toggle between controls and I/O overlays
            activeOverlay = (activeOverlay == "controls") and "io" or "controls"

            -- Store current window position
            local x, y = love.window.getPosition()

            -- Fixed window width that doesn't change
            local windowWidth = scaledDisplayWidth

            -- Get window height from the function using the new overlay type
            local windowHeight = calculateWindowHeight(activeOverlay)

            -- Set new window size and restore position
            love.window.setMode(windowWidth, windowHeight,
                                {resizable = false, msaa = 8, vsync = 1})
            love.window.setPosition(x, y)
        end
        return
    end

    -- Continue with normal keypressed handling...

    if key == "r" and love.keyboard.isDown("lctrl") then
        -- Ctrl+R: Force script reload
        print("Manual reload triggered...")
        local newScript, newScriptParameters = loadScript(scriptPath)

        if newScript then
            -- Store previous I/O connections
            local prevInputAssignments = scriptInputAssignments
            local prevOutputAssignments = scriptOutputAssignments

            -- Update the script
            script = newScript
            scriptParameters = newScriptParameters

            -- Reset and update control callbacks in case script has changed
            local controlCallbacks = {
                onButtonPress = function(buttonIndex)
                    if script then
                        local functionName = "button" .. buttonIndex .. "Push"
                        if script[functionName] then
                            print("Button " .. buttonIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        elseif script.button then
                            print("Button " .. buttonIndex ..
                                      " pressed, calling script.button")
                            safeScriptCall(script.button, script, buttonIndex,
                                           true)
                        end
                    end
                end,
                onButtonRelease = function(buttonIndex)
                    if script then
                        local functionName =
                            "button" .. buttonIndex .. "Release"
                        if script[functionName] then
                            print("Button " .. buttonIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        elseif script.button then
                            print("Button " .. buttonIndex ..
                                      " released, calling script.button")
                            safeScriptCall(script.button, script, buttonIndex,
                                           false)
                        end
                    end
                end,
                onPotChange = function(potIndex, value)
                    if script then
                        local functionName = "pot" .. potIndex .. "Turn"
                        if script[functionName] then
                            print(
                                "Pot " .. potIndex .. " changed to " .. value ..
                                    ", calling script." .. functionName)
                            safeScriptCall(script[functionName], script, value)
                        elseif script.pot then
                            print(
                                "Pot " .. potIndex .. " changed to " .. value ..
                                    ", calling script.pot")
                            safeScriptCall(script.pot, script, potIndex, value)
                        end
                    end
                end,
                onPotPress = function(potIndex)
                    if script then
                        local functionName = "pot" .. potIndex .. "Push"
                        if script[functionName] then
                            print("Pot " .. potIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onPotRelease = function(potIndex)
                    if script then
                        local functionName = "pot" .. potIndex .. "Release"
                        if script[functionName] then
                            print("Pot " .. potIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onEncoderChange = function(encoderIndex, delta)
                    if script then
                        local functionName = "encoder" .. encoderIndex .. "Turn"
                        if script[functionName] then
                            print(
                                "Encoder " .. encoderIndex .. " changed by " ..
                                    delta .. ", calling script." .. functionName)
                            safeScriptCall(script[functionName], script, delta)
                        elseif script.encoder then
                            print(
                                "Encoder " .. encoderIndex .. " changed by " ..
                                    delta .. ", calling script.encoder")
                            safeScriptCall(script.encoder, script, encoderIndex,
                                           delta)
                        end
                    end
                end,
                onEncoderPress = function(encoderIndex)
                    if script then
                        local functionName = "encoder" .. encoderIndex .. "Push"
                        if script[functionName] then
                            print("Encoder " .. encoderIndex ..
                                      " pressed, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end,
                onEncoderRelease = function(encoderIndex)
                    if script then
                        local functionName =
                            "encoder" .. encoderIndex .. "Release"
                        if script[functionName] then
                            print("Encoder " .. encoderIndex ..
                                      " released, calling script." ..
                                      functionName)
                            safeScriptCall(script[functionName], script)
                        end
                    end
                end
            }
            controls.setCallbacks(controlCallbacks)

            -- Set active overlay based on script callbacks
            if hasControlCallbacks(script) then
                activeOverlay = "controls"

                -- Update window height to match if changed
                local wx, wy = love.window.getPosition()
                love.window.setMode(scaledDisplayWidth,
                                    calculateWindowHeight(activeOverlay),
                                    {resizable = false, msaa = 8, vsync = 1})
                love.window.setPosition(wx, wy)
            end

            -- Recalculate I/O counts
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

            -- Restore previous I/O connections where possible
            scriptInputAssignments = {}
            scriptOutputAssignments = {}

            for i = 1, scriptInputCount do
                scriptInputAssignments[i] = prevInputAssignments[i]
            end

            for i = 1, scriptOutputCount do
                scriptOutputAssignments[i] = prevOutputAssignments[i]
            end

            -- Reset outputs that are no longer connected after reload
            for i = 1, 8 do -- 8 physical outputs
                local stillConnected = false
                for _, physOutput in pairs(scriptOutputAssignments) do
                    if physOutput == i then
                        stillConnected = true
                        break
                    end
                end
                if not stillConnected then currentOutputs[i] = 0 end
            end

            print("Script reloaded successfully!")

            -- Mark the reload blink state
            reloadBlink = true
            lastReloadTime = time
        else
            print("Error reloading script, continuing with previous version")
        end
        return
    elseif key == "h" and love.keyboard.isDown("lctrl") then
        -- Ctrl+H: Toggle hot reload
        enableAutoReload = not enableAutoReload
        print("Hot reload:", enableAutoReload and "enabled" or "disabled")
        return
    elseif key == "o" and love.keyboard.isDown("lctrl") then
        -- Ctrl+O: Toggle OSC
        osc_client.toggle()
        return
    elseif key == "d" and love.keyboard.isDown("lctrl") then
        -- Ctrl+D: Toggle debug mode
        debugMode = not debugMode
        print("Debug mode:", debugMode and "enabled" or "disabled")
        return
    elseif key == "s" and love.keyboard.isDown("lctrl") then
        -- Ctrl+S: Save current I/O mappings
        markMappingsChanged() -- Mark as changed to force save
        saveIOState()
        print("I/O mappings manually saved to " .. stateFile)
        return
    end
end

-- Modify keyreleased to support minimal mode
function M.keyreleased(key)
    -- Let minimal mode handle if active
    if minimalModeEnabled then MinimalMode.keyreleased(key) end

    -- Continue with normal key release handling...
end

function M.mousepressed(x, y, button)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / uiScaleFactor +
                 (displayAreaHeight / uiScaleFactor)
    else
        ly = y / uiScaleFactor
    end

    -- First check if controls handled the event
    if controls.mousepressed(lx, ly, button) then return end

    local currentTime = love.timer.getTime()
    local isDoubleClick = false

    -- Check for double click
    if button == 1 and lastClickTime and (currentTime - lastClickTime) <
        doubleClickThreshold then isDoubleClick = true end

    -- Check for right-click on physical inputs (for scaling)
    if button == 2 then
        -- Right-click on physical inputs
        local inputPos = io_panel.getPhysicalInputPositions()
        if inputPos then
            for i, pos in ipairs(inputPos) do
                local dx = lx - pos[1]
                local dy = ly - pos[2]
                if math.sqrt(dx * dx + dy * dy) <= 15 then
                    -- Allow scaling for both normal and clock inputs
                    scalingInput = i
                    scaleDragStartY = ly
                    return
                end
            end
        end
    end

    -- Check parameter knobs
    if scriptParameters then
        local params = {
            scriptParameters = scriptParameters,
            displayWidth = displayWidth,
            panelY = lastPhysicalIOBottomY + 24, -- Use the stored Y position
            knobRadius = paramKnobRadius,
            knobSpacing = paramKnobSpacing
        }
        for i, sp in ipairs(scriptParameters) do
            local knobX, knobY = parameter_knobs.getKnobPosition(i, params)
            local dx = lx - knobX
            local dy = ly - knobY
            if dx * dx + dy * dy <= paramKnobRadius ^ 2 then
                if isDoubleClick and lastClickType == "knob" and lastClickIndex ==
                    i then
                    -- Double-clicked on parameter knob - reset to default value
                    if sp.default then
                        -- Clear any automation
                        if parameterAutomation[i] then
                            print("Removed automation for parameter " .. i ..
                                      " (" .. sp.name .. ")")
                            parameterAutomation[i] = nil
                            sp.baseValue = nil
                        end

                        -- Reset to default value
                        sp.current = sp.default
                        -- Update the script's parameters using the helper module
                        helpers.updateScriptParameters(scriptParameters, script)
                        print("Reset parameter " .. i .. " (" .. sp.name ..
                                  ") to default value: " .. sp.default)
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return
                end

                -- Start knob drag for normal click
                if button == 1 then
                    knobDragIndex = i
                    knobDragStartY = ly
                    knobDragStartVal = sp.current
                    dragX = lx -- Initialize horizontal drag position
                    dragY = ly -- Initialize vertical drag position

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "knob"
                    lastClickIndex = i
                    return
                end
            end
        end
    end

    -- Script inputs
    local scriptInputPos = io_panel.getScriptInputPositions()
    if scriptInputPos then
        for i, pos in ipairs(scriptInputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 12 then
                if isDoubleClick and lastClickType == "scriptInput" and
                    lastClickIndex == i then
                    -- Double-clicked on script input - clear assignment
                    if scriptInputAssignments[i] then
                        print("Cleared input assignment for script input " .. i)
                        scriptInputAssignments[i] = nil
                        markMappingsChanged()
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return
                end

                -- Store click for double-click detection
                lastClickTime = currentTime
                lastClickType = "scriptInput"
                lastClickIndex = i
                return
            end
        end
    end

    -- Script outputs
    local scriptOutputPos = io_panel.getScriptOutputPositions()
    if scriptOutputPos then
        for i, pos in ipairs(scriptOutputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 12 then
                if isDoubleClick and lastClickType == "scriptOutput" and
                    lastClickIndex == i then
                    -- Double-clicked on script output - clear assignment
                    if scriptOutputAssignments[i] then
                        -- Clear voltage on the physical output that was connected
                        currentOutputs[scriptOutputAssignments[i]] = 0
                        print("Cleared output assignment for script output " ..
                                  i)
                        scriptOutputAssignments[i] = nil
                        markMappingsChanged()
                    end

                    -- Reset double-click state
                    lastClickTime = 0
                    return
                end

                -- Store click for double-click detection
                lastClickTime = currentTime
                lastClickType = "scriptOutput"
                lastClickIndex = i
                return
            end
        end
    end

    -- Physical inputs
    local inputPos = io_panel.getPhysicalInputPositions()
    if inputPos then
        for i, pos in ipairs(inputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                if button == 2 then
                    -- Right button is only for dragging to set attenuation level
                    pendingPress = true
                    pendingType = "input"
                    pendingIndex = i
                    pressX, pressY = lx, ly
                    return
                elseif button == 1 then
                    if isDoubleClick and lastClickType == "physicalInput" and
                        lastClickIndex == i then
                        -- Double click to reset to default state
                        local changed = (inputClock[i] ~= false) or
                                            (inputPolarity[i] ~= kBipolar) or
                                            (inputScaling[i] ~= 1.0)

                        inputClock[i] = false
                        inputPolarity[i] = kBipolar
                        inputScaling[i] = 1.0

                        if changed then
                            markMappingsChanged() -- Mark as changed when reset
                        end

                        print("Reset input " .. i ..
                                  " to default state (bipolar, no attenuation)")

                        -- Remove any pending actions for this input
                        for j = #pendingClickActions, 1, -1 do
                            if pendingClickActions[j].type == "cycleInputMode" and
                                pendingClickActions[j].inputIndex == i then
                                table.remove(pendingClickActions, j)
                            end
                        end

                        -- Reset double-click state
                        lastClickTime = 0
                        return
                    end

                    pendingPress = true
                    pendingType = "input"
                    pendingIndex = i
                    pressX, pressY = lx, ly

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "physicalInput"
                    lastClickIndex = i
                    return
                end
            end
        end
    end

    -- Physical outputs
    local outputPos = io_panel.getPhysicalOutputPositions()
    if outputPos then
        for i, pos in ipairs(outputPos) do
            local dx = lx - pos[1]
            local dy = ly - pos[2]
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                if button == 1 then
                    pendingPress = true
                    pendingType = "output"
                    pendingIndex = i
                    pressX, pressY = lx, ly

                    -- Store click for double-click detection
                    lastClickTime = currentTime
                    lastClickType = "physicalOutput"
                    lastClickIndex = i
                    return
                end
            end
        end
    end

    -- Reset double-click detection if clicking elsewhere
    lastClickTime = 0
    lastClickType = nil
    lastClickIndex = nil
end

function M.mousemoved(x, y, dx, dy)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / uiScaleFactor +
                 (displayAreaHeight / uiScaleFactor)
    else
        ly = y / uiScaleFactor
    end

    -- First check if controls handled the event
    if controls.mousemoved(lx, ly, dx, dy) then return end

    -- Handle scaling inputs with vertical drag
    if scalingInput then
        local deltaY = scaleDragStartY - ly

        if inputClock[scalingInput] then
            -- For clock inputs, modify the BPM instead of scaling
            -- Use a less sensitive adjustment for BPM
            local bpmDelta = deltaY * 1.0 -- Reduced from 2.0 to 1.0
            local newBPM = clockBPM + bpmDelta
            newBPM = math.max(minBPM, math.min(maxBPM, newBPM))

            if newBPM ~= clockBPM then
                clockBPM = newBPM
                markMappingsChanged() -- Mark as changed when BPM changes
                print(string.format("Clock BPM adjusted to: %.1f", clockBPM))
            end
        else
            -- For normal inputs, adjust scaling as before
            local newScale = inputScaling[scalingInput] +
                                 (deltaY * scaleDragSensitivity)
            newScale = math.max(0.0, math.min(1.0, newScale))

            if newScale ~= inputScaling[scalingInput] then
                inputScaling[scalingInput] = newScale
                markMappingsChanged() -- Mark as changed when scaling changes
            end
        end

        scaleDragStartY = ly
        return
    end

    -- Handle pending press that could become a drag
    if pendingPress and not dragging then
        local dist = math.sqrt((lx - pressX) ^ 2 + (ly - pressY) ^ 2)
        if dist > clickThreshold then
            dragging = true
            dragType = pendingType
            dragIndex = pendingIndex
            dragX = lx
            dragY = ly
            pendingPress = false
        end
    end

    -- Update drag line position
    if dragging then
        dragX = lx
        dragY = ly
    end

    -- Handle parameter knob dragging
    if knobDragIndex then
        local sp = scriptParameters[knobDragIndex]
        if sp then
            -- Handle dragging differently based on automation
            local isAutomated = parameterAutomation[knobDragIndex] ~= nil

            if sp.type == "integer" then
                -- Integer parameters always use whole number steps
                local stepSize = y > 0 and -1 or 1

                if isAutomated then
                    local newBaseVal = (sp.baseValue or sp.current) + stepSize
                    newBaseVal = math.floor(
                                     math.max(sp.min,
                                              math.min(sp.max, newBaseVal)) +
                                         0.5)
                    sp.baseValue = newBaseVal
                else
                    local newVal = sp.current + stepSize
                    newVal = math.floor(math.max(sp.min,
                                                 math.min(sp.max, newVal)) + 0.5)
                    sp.current = newVal
                end

            elseif sp.type == "float" then
                -- Float parameters use scaled values
                local range = sp.max - sp.min
                local stepSize = -y * (range / 200) -- Adjust sensitivity based on parameter range

                if isAutomated then
                    local newBaseVal = (sp.baseValue or sp.current) + stepSize
                    newBaseVal = math.max(sp.min, math.min(sp.max, newBaseVal))
                    sp.baseValue = newBaseVal
                else
                    local newVal = sp.current + stepSize
                    newVal = math.max(sp.min, math.min(sp.max, newVal))
                    sp.current = newVal
                end

            else -- enum type
                -- Enum parameters always use whole number indices
                local intDelta = y > 0 and -1 or 1 -- Flip direction for more intuitive control

                if isAutomated then
                    local newBaseIndex = (sp.baseValue or sp.current) + intDelta
                    newBaseIndex = math.max(1,
                                            math.min(#sp.values, newBaseIndex))
                    sp.baseValue = newBaseIndex
                else
                    local newIndex = sp.current + intDelta
                    newIndex = math.max(1, math.min(#sp.values, newIndex))
                    sp.current = newIndex
                end
            end

            -- Update the script's parameters immediately
            helpers.updateScriptParameters(scriptParameters, script)
        end
    end

    -- Update active knob for wheel control
    if scriptParameters then
        local params = {
            scriptParameters = scriptParameters,
            displayWidth = displayWidth,
            panelY = lastPhysicalIOBottomY + 24, -- Use the stored Y position
            knobRadius = paramKnobRadius,
            knobSpacing = paramKnobSpacing
        }

        -- Reset active knob
        activeKnob = nil

        -- Check if mouse is over any knob
        for i, sp in ipairs(scriptParameters) do
            local knobX, knobY = parameter_knobs.getKnobPosition(i, params)
            local dx = lx - knobX
            local dy = ly - knobY
            if dx * dx + dy * dy <= paramKnobRadius * paramKnobRadius then
                activeKnob = i
                break
            end
        end
    end
end

function M.mousereleased(x, y, button)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = x / uiScaleFactor
    local ly = y
    if y > displayAreaHeight then
        ly = (y - displayAreaHeight) / uiScaleFactor +
                 (displayAreaHeight / uiScaleFactor)
    else
        ly = y / uiScaleFactor
    end

    -- First check if controls handled the event
    if controls.mousereleased(lx, ly, button) then return end

    -- If we were scaling an input, stop now
    if scalingInput then
        scalingInput = nil
        return
    end

    -- Handle pending press that didn't become a drag
    if pendingPress then
        if pendingType == "input" then
            -- Check if this input is connected to a kTrigger script input
            local isTriggerInput = false
            local scriptInputIdx = nil
            for idx, assignedPhysInput in pairs(scriptInputAssignments) do
                if assignedPhysInput == pendingIndex and type(script.inputs) ==
                    "table" and script.inputs[idx] == kTrigger then
                    isTriggerInput = true
                    scriptInputIdx = idx
                    break
                end
            end

            if isTriggerInput and scriptInputIdx then
                -- For trigger inputs, send a 10ms pulse
                triggerPulseActive[pendingIndex] = true
                triggerPulseTimes[pendingIndex] = time
                -- Call the script's trigger function if it exists
                if script.trigger then
                    -- Pass the script input index, not the physical input index
                    safeScriptCall(script.trigger, script, scriptInputIdx)
                end
            else
                -- For non-trigger inputs, cycle through modes as before
                local currentTime = love.timer.getTime()
                table.insert(pendingClickActions, {
                    type = "cycleInputMode",
                    inputIndex = pendingIndex,
                    executeAfter = currentTime + doubleClickThreshold
                })
            end
        end
        pendingPress = false
        return
    end

    -- Handle dragging connections
    if dragging then
        if dragType == "input" then
            -- Check if we're over a parameter knob
            if scriptParameters then
                local params = {
                    scriptParameters = scriptParameters,
                    displayWidth = displayWidth,
                    panelY = lastPhysicalIOBottomY + 24,
                    knobRadius = paramKnobRadius,
                    knobSpacing = paramKnobSpacing
                }

                for i, sp in ipairs(scriptParameters) do
                    local knobX, knobY =
                        parameter_knobs.getKnobPosition(i, params)
                    local dx = lx - knobX
                    local dy = ly - knobY
                    if dx * dx + dy * dy <= paramKnobRadius * paramKnobRadius then
                        -- Store the current value as the base value before automation
                        sp.baseValue = sp.current
                        -- Link the physical input to this parameter
                        parameterAutomation[i] = dragIndex
                        print(string.format(
                                  "Linked physical input %d to parameter %d (%s)",
                                  dragIndex, i, sp.name))
                        break
                    end
                end
            end

            -- Check if we're over a script input
            local scriptInputPos = io_panel.getScriptInputPositions()
            if scriptInputPos then
                for i, pos in ipairs(scriptInputPos) do
                    local dx = lx - pos[1]
                    local dy = ly - pos[2]
                    if math.sqrt(dx * dx + dy * dy) <= 12 then
                        scriptInputAssignments[i] = dragIndex
                        markMappingsChanged()
                        print("Connected physical input " .. dragIndex ..
                                  " to script input " .. i)
                        break
                    end
                end
            end
        elseif dragType == "output" then
            -- Check if we're over a script output
            local scriptOutputPos = io_panel.getScriptOutputPositions()
            if scriptOutputPos then
                for i, pos in ipairs(scriptOutputPos) do
                    local dx = lx - pos[1]
                    local dy = ly - pos[2]
                    if math.sqrt(dx * dx + dy * dy) <= 12 then
                        scriptOutputAssignments[i] = dragIndex
                        markMappingsChanged()
                        print("Connected script output " .. i ..
                                  " to physical output " .. dragIndex)
                        break
                    end
                end
            end
        end
        dragging = false
    end

    -- Reset knob dragging state
    if knobDragIndex then knobDragIndex = nil end
end

function M.wheelmoved(x, y)
    -- Adjust y coordinate based on display area at the top
    local displayAreaHeight = scaledDisplayHeight

    -- Calculate scaled coordinates
    local lx = love.mouse.getX() / uiScaleFactor
    local ly = love.mouse.getY()
    if ly > displayAreaHeight then
        ly = (ly - displayAreaHeight) / uiScaleFactor +
                 (displayAreaHeight / uiScaleFactor)
    else
        ly = ly / uiScaleFactor
    end

    -- First check if controls handled the event
    if controls.wheelmoved(x, y) then return end

    -- Handle parameter knob wheel control
    if activeKnob and scriptParameters and activeKnob <= #scriptParameters then
        local param = scriptParameters[activeKnob]
        local step = 1

        -- Adjust step size based on parameter type
        if param.type == "float" then
            if param.scale == kBy10 then
                -- For kBy10, use step of 1.0 in display units
                step = 1.0
            elseif param.scale == kBy100 then
                -- For kBy100, use step of 1.0 in display units
                step = 1.0
            elseif param.scale == kBy1000 then
                -- For kBy1000, use step of 1.0 in display units
                step = 1.0
            else
                step = 0.1 -- Default for float without scaling
            end
        end

        -- y is positive for scroll up (increase) and negative for scroll down (decrease)
        local newValue = param.current + (y * step)

        -- Clamp the value within range based on parameter type
        if param.type == "enum" then
            -- For enum parameters, clamp between 1 and the number of values
            if param.values then
                newValue = math.max(1, math.min(#param.values, newValue))
            end
        else
            -- For numeric parameters (integer, float), use min/max
            newValue = math.max(param.min, math.min(param.max, newValue))
        end

        -- Only update if value actually changed
        if newValue ~= param.current then
            -- For automated parameters, adjust the base value to maintain the same CV offset
            if parameterAutomation[activeKnob] then
                local cvOffset = param.current -
                                     (param.baseValue or param.current)
                param.baseValue = newValue - cvOffset
            end
            param.current = newValue

            -- Update the script's parameters using the helper module
            helpers.updateScriptParameters(scriptParameters, script)

            -- Print debug info
            debug_utils.debugLog(string.format(
                                     "Parameter %d (%s) value changed: %.3f",
                                     activeKnob, param.name, newValue))
        end

        return true
    end

    -- Handle any other wheel events here if needed
end

function M.quit()
    -- Save IO mappings
    saveIOState()

    -- Clean up OSC client
    osc_client.cleanup()
end

-- Accessor for debug mode
function M.isDebugMode() return debugMode end

-- Public function to load a script from a path
function M.loadScriptFromPath(filePath)
    if not filePath then return end

    print("Loading script from path:", filePath)

    -- Update scriptPath and load the script
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
        -- Store previous I/O connections
        local prevInputAssignments = scriptInputAssignments
        local prevOutputAssignments = scriptOutputAssignments

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

        -- Clear existing assignments
        for i = 1, scriptInputCount do scriptInputAssignments[i] = nil end
        for i = 1, scriptOutputCount do scriptOutputAssignments[i] = nil end

        -- Create default mappings for the new script
        createDefaultMappings()

        -- Update minimal mode parameters
        MinimalMode.setParameters(scriptParameters)

        -- Show notification
        showNotification("Script loaded: " .. filePath:match("([^/]+)%.lua$"))

        return true
    else
        -- Show error notification
        showErrorNotification("Failed to load script: " .. filePath)
        return false
    end
end

return M
