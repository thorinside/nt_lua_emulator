-- emulator.lua
local M = {} -- We'll return this table.

-- Import refactored modules
local scriptLoader = require("modules.script_loader")
local ioState = require("modules.io_state")
local notifications = require("modules.notifications")
local inputHandler = require("modules.input_handler")
local windowManager = require("modules.window_manager")
local parameterManager = require("modules.parameter_manager")
local signalProcessor = require("modules.signal_processor")
local uiState = require("modules.ui_state")
local scriptManager = require("modules.script_manager")

-- Initialize the script loader with notification functions
scriptLoader.init({
    showNotification = function(message)
        notifications.showNotification(message)
    end,
    showErrorNotification = function(message)
        notifications.showErrorNotification(message)
    end
})

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
-- Use a default script path that will be overridden by state.json if available
local scriptPath = "test_script.lua" -- Default path

--------------------------------------------------------------------------------
-- Runtime State
--------------------------------------------------------------------------------
local script
local time = 0

-- IO state
currentOutputs = {}
currentInputs = {}

local scriptInputCount = 0
local scriptOutputCount = 0
local scriptInputAssignments = {}
local scriptOutputAssignments = {}

local prevGateStates = {}

-- Parameter automation
local parameterAutomation = {}

-- Configuration state
local stateFile = "state.json"

-- Local vars for caching 
local fontDefault, fontSmall

-- Function to show notifications (delegate to notifications module)
local function showNotification(message) notifications.showNotification(message) end

-- Function to show error notifications (delegate to notifications module)
local function showErrorNotification(message)
    notifications.showErrorNotification(message)
end

-- Function to safely call script functions with pcall (delegate to scriptLoader)
local function safeScriptCall(func, scriptObj, ...)
    if not func then return nil end

    local status, result = pcall(func, scriptObj, ...)
    if not status then
        showErrorNotification("Script error: " .. tostring(result))
        return nil
    end
    return result
end

-- Create default mappings (first n inputs, first m outputs) (delegate to ioState)
local function createDefaultMappings()
    scriptInputAssignments, scriptOutputAssignments =
        ioState.createDefaultMappings(scriptInputCount, scriptOutputCount,
                                      scriptInputAssignments,
                                      scriptOutputAssignments)
end

-- Mark that mappings have changed (delegate to ioState)
local function markMappingsChanged() ioState.markMappingsChanged() end

-- Save current IO mappings to state.json (delegate to ioState)
local function saveIOState(forceSave)
    -- Prepare state object
    local state = {
        scriptPath = scriptPath,
        inputs = {},
        outputs = {},
        inputModes = {}, -- Add storage for input modes
        oscEnabled = osc_client.isEnabled(), -- Save OSC enabled state
        clockBPM = signalProcessor.getClockBPM(), -- Save global clock BPM setting
        minimalMode = windowManager.isMinimalMode(), -- Save minimal mode state
        activeOverlay = windowManager.getActiveOverlay() -- Save active overlay state
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

    -- Get input states from signal processor
    local inputClock = signalProcessor.getInputClock()
    local inputPolarity = signalProcessor.getInputPolarity()
    local inputScaling = signalProcessor.getInputScaling()

    -- Save input modes and scaling
    for i = 1, 12 do -- 12 physical inputs
        state.inputModes[tostring(i)] = {
            clock = inputClock[i] or false,
            polarity = inputPolarity[i] or kBipolar,
            scaling = inputScaling[i] or 1.0
        }
    end

    -- Save script state by calling serialise if it exists
    if script and script.serialise then
        local scriptState = scriptLoader.serialiseState(script)
        if scriptState then state.scriptState = scriptState end
    end

    ioState.saveIOState(state, forceSave)
end

-- Load IO mappings from state.json (delegate to ioState)
local function loadIOState()
    local success, state = ioState.loadIOState(scriptPath)
    if not success then return false end

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
                    signalProcessor.setInputClock(idx, modeData.clock)
                end
                if modeData.polarity ~= nil then
                    signalProcessor.setInputPolarity(idx, modeData.polarity)
                end
                if modeData.scaling ~= nil then
                    signalProcessor.setInputScaling(idx, modeData.scaling)
                end
            end
        end
        print("Input modes and scaling restored from state file")
    end

    -- Load the clock BPM if present
    if state.clockBPM then
        signalProcessor.setClockBPM(state.clockBPM)
        print("Clock BPM restored: " .. state.clockBPM .. " BPM")
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

    -- Restore minimal mode state if present
    if state.minimalMode ~= nil then
        windowManager.setMinimalMode(state.minimalMode)
    end

    print("IO mappings loaded from " .. stateFile)
    return true
end

-- Load a script and initialize it
local function loadScript(scriptPathToLoad)
    -- Extend the script loader initialization with current script path
    scriptLoader.init({
        showNotification = showNotification,
        showErrorNotification = showErrorNotification,
        scriptPath = scriptPathToLoad
    })

    local scriptObj, scriptParams = scriptLoader.loadScript(scriptPathToLoad,
                                                            createDefaultMappings)

    if scriptObj then
        scriptManager.setScript(scriptObj)

        -- Set up control callbacks
        scriptManager.setupControlCallbacks(scriptObj)
    end

    return scriptObj, scriptParams
end

--------------------------------------------------------------------------------
-- The Emulator Module Functions
--------------------------------------------------------------------------------
function M.load()
    -- Initialize the OSC client first
    osc_client.init()

    -- Initialize UI components
    fontDefault = love.graphics.newFont(14) -- Default font at original size
    fontSmall = love.graphics.newFont(12) -- Small font at original size

    -- Initialize window manager
    windowManager.init({
        display = display,
        io_panel = io_panel,
        controls = controls,
        MinimalMode = MinimalMode
    })

    -- Configure display
    display.init({
        width = 256,
        height = 64,
        scaling = 3.0, -- Use the full display scale factor
        baseColor = {0, 1, 1} -- Teal base color for display
    })

    -- Set window title
    love.window.setTitle("Disting NT LUA Emulator")

    -- Set global line style for smoother lines
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("miter")

    -- Initialize signal processor
    signalProcessor.init({safeScriptCall = safeScriptCall})

    -- Initialize parameter manager
    parameterManager.init({helpers = helpers})

    -- Initialize UI state manager
    uiState.init({})

    -- Initialize script manager
    scriptManager.init({
        scriptLoader = scriptLoader,
        safeScriptCall = safeScriptCall,
        controls = controls,
        notifications = notifications
    })

    -- Initialize input handler
    inputHandler.init({
        display = display,
        io_panel = io_panel,
        controls = controls,
        parameter_knobs = parameter_knobs,
        helpers = helpers,
        notifications = notifications,
        markMappingsChanged = markMappingsChanged,
        saveIOState = saveIOState,
        signalProcessor = signalProcessor
    })

    -- Try to load script path from state.json first
    local stateFile = io.open("state.json", "r")
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()
        local success, result = pcall(json.decode, content)
        if success and result.scriptPath then
            scriptPath = result.scriptPath
            scriptManager.setScriptPath(scriptPath)
        end
    end

    -- Load the script
    script, scriptParameters = loadScript(scriptPath)

    if not script then
        print("Failed to load script:", scriptPath)
        return
    end

    -- Determine input/output counts from the script
    scriptInputCount, scriptOutputCount = scriptManager.getScriptIOCounts()

    -- Set parameters in manager
    parameterManager.setParameters(scriptParameters, script)

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
    if true then
        MinimalMode.init(display, scriptParameters,
                         function(paramIndex, newValue)
            -- Update the parameter in parameterManager
            parameterManager.updateParameterValue(paramIndex, newValue)
        end)
    end

    -- Update window manager state with script information
    windowManager.setState({
        script = script,
        scriptInputCount = scriptInputCount,
        scriptOutputCount = scriptOutputCount,
        scriptParameters = parameterManager.getParameters(),
        fontSmall = fontSmall
    })

    -- If we're in minimal mode, make sure the window size is exactly right
    -- This ensures we don't get a visual jump from default size to minimal size
    if windowManager.isMinimalMode() then
        -- Force resize right away with exact display dimensions
        local scaledDisplayWidth, scaledDisplayHeight =
            windowManager.getScaledDisplayDimensions()
        love.window.setMode(scaledDisplayWidth, scaledDisplayHeight,
                            {resizable = false, msaa = 8, vsync = 1})

        -- Activate minimal mode UI
        MinimalMode.activate()

        print("Started in minimal mode with display dimensions")
    else
        -- Now resize the window with complete information
        local width, height = windowManager.resizeWindow()
    end
end

function M.update(dt)
    -- Update UI state
    uiState.update(dt)

    -- Update notifications system
    notifications.update(dt)

    -- Update minimal mode state if active
    if windowManager.isMinimalMode() then MinimalMode.update(dt) end

    -- Update time counter and trigger pulse states
    time = signalProcessor.updateTime(dt)
    signalProcessor.updateTriggerPulses()

    -- Update active state based on current overlay and minimal mode
    controls.setActive(windowManager.getActiveOverlay() == "controls" and
                           not windowManager.isMinimalMode())

    -- Only proceed with update if we have a valid script
    if not script then return end

    -- Check for script file modification and reload if needed
    if scriptManager.checkScriptModified(time) then
        -- Save window position before making any changes
        local windowX, windowY = love.window.getPosition()

        -- Save current IO mappings before reload
        saveIOState()

        -- Invalidate window height cache when script is reloaded
        windowManager.invalidateCache()

        -- Reload the script
        local success, newScript, newScriptParameters =
            scriptManager.reloadScript(createDefaultMappings,
                                       scriptInputAssignments,
                                       scriptOutputAssignments)

        if success then
            -- Store previous I/O connections
            local prevInputAssignments = scriptInputAssignments
            local prevOutputAssignments = scriptOutputAssignments

            -- Update script and parameters
            script = newScript
            scriptParameters = newScriptParameters

            -- Update parameter manager
            parameterManager.setParameters(scriptParameters, script)

            -- Recalculate I/O counts
            scriptInputCount, scriptOutputCount =
                scriptManager.getScriptIOCounts()

            -- Restore previous I/O connections where possible
            scriptInputAssignments = {}
            scriptOutputAssignments = {}

            for i = 1, scriptInputCount do
                scriptInputAssignments[i] = prevInputAssignments[i]
            end

            for i = 1, scriptOutputCount do
                scriptOutputAssignments[i] = prevOutputAssignments[i]
            end

            -- Reset outputs that are no longer connected
            signalProcessor.resetUnconnectedOutputs(scriptOutputAssignments)

            -- Resize window to fit content (but don't change the overlay mode)
            windowManager.resizeWindow()

            -- Always restore window position after resize
            love.window.setPosition(windowX, windowY)

            print("Script reloaded successfully!")
        end

        return
    end

    -- Update reload blink state
    scriptManager.updateReloadBlink(time)

    -- Update pending click actions
    inputHandler.updatePendingClicks(love.timer.getTime())

    -- Update state for input handler
    inputHandler.setState({
        script = script,
        scriptInputCount = scriptInputCount,
        scriptOutputCount = scriptOutputCount,
        scriptInputAssignments = scriptInputAssignments,
        scriptOutputAssignments = scriptOutputAssignments,
        currentInputs = currentInputs,
        currentOutputs = currentOutputs,
        inputClock = signalProcessor.getInputClock(),
        inputPolarity = signalProcessor.getInputPolarity(),
        inputScaling = signalProcessor.getInputScaling(),
        clockBPM = signalProcessor.getClockBPM(),
        minBPM = signalProcessor.getBPMRange(),
        maxBPM = 200,
        scriptParameters = parameterManager.getParameters(),
        parameterAutomation = parameterManager.getParameterAutomation(),
        triggerPulseActive = signalProcessor.getTriggerPulseStates().active,
        triggerPulseTimes = signalProcessor.getTriggerPulseStates().times,
        time = time,
        lastPhysicalIOBottomY = io_panel.getLastPhysicalIOBottomY(),
        paramKnobRadius = 12,
        paramKnobSpacing = 80,
        uiScaleFactor = windowManager.getUIScaleFactor(),
        scaledDisplayHeight = select(2,
                                     windowManager.getScaledDisplayDimensions()),
        safeScriptCall = safeScriptCall
    })

    -- Update state for window manager
    windowManager.setState({
        script = script,
        scriptInputCount = scriptInputCount,
        scriptOutputCount = scriptOutputCount,
        scriptParameters = parameterManager.getParameters(),
        fontSmall = fontSmall
    })

    -- Update input values
    currentInputs = signalProcessor.updateInputs(scriptInputAssignments, script)

    -- Update automated parameters
    parameterManager.updateAutomatedParameters(currentInputs,
                                               signalProcessor.getInputPolarity())

    -- Create inputs table to pass to script.step
    local scriptInputValues = signalProcessor.prepareScriptInputValues(
                                  scriptInputCount, scriptInputAssignments)

    -- Reset unconnected outputs
    signalProcessor.resetUnconnectedOutputs(scriptOutputAssignments)

    -- Call the script's step function to update outputs
    local outputValues = scriptManager.callScriptStep(dt, scriptInputValues)

    -- Update outputs with values from script
    if outputValues then
        currentOutputs = signalProcessor.updateOutputs(outputValues,
                                                       scriptOutputAssignments)
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
end

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
    scriptManager.callScriptDraw()

    -- Reset canvas state
    love.graphics.setCanvas()
    love.graphics.pop()

    -- Reset color to white after canvas operations
    love.graphics.setColor(1, 1, 1, 1)

    -- If in minimal mode, use minimal mode drawing
    if windowManager.isMinimalMode() then
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
        local scaledDisplayWidth, scaledDisplayHeight =
            windowManager.getScaledDisplayDimensions()
        love.graphics.rectangle("line", 0, 0, scaledDisplayWidth,
                                scaledDisplayHeight)

        -- Draw the active overlay
        if windowManager.getActiveOverlay() == "controls" then
            -- Draw the controls section below the display
            controls.layout(0, 0, scaledDisplayWidth, scaledDisplayHeight)
            controls.draw()
        else
            -- Draw Script I/O panel (inputs & outputs)
            local layout = windowManager.getLayoutPositions()
            io_panel.drawScriptIO({
                script = script,
                font = fontSmall,
                inputCount = scriptInputCount,
                outputCount = scriptOutputCount,
                inputAssignments = scriptInputAssignments,
                outputAssignments = scriptOutputAssignments,
                ioY = layout.scriptIOPanelY,
                cellH = 40
            })

            -- Draw Physical I/O grids
            local physicalIOBottomY = io_panel.drawPhysicalIO({
                currentInputs = currentInputs,
                currentOutputs = currentOutputs,
                inputClock = signalProcessor.getInputClock(),
                inputPolarity = signalProcessor.getInputPolarity(),
                inputScaling = signalProcessor.getInputScaling(),
                clockBPM = signalProcessor.getClockBPM(),
                font = fontDefault,
                physInputX = 40,
                physInputY = layout.physicalIOStartY,
                cellW = 40,
                cellH = 40
            })

            -- Store the bottom Y position for use by the input handler
            io_panel.setLastPhysicalIOBottomY(physicalIOBottomY)

            -- Display BPM if there's at least one clock input
            local hasClockInput = false
            local inputClock = signalProcessor.getInputClock()
            for i = 1, 12 do
                if inputClock[i] then
                    hasClockInput = true
                    break
                end
            end

            if hasClockInput then
                -- Center BPM text specifically under the bottom row of inputs (9-12)
                love.graphics.setColor(1, 1, 1, 0.5) -- 50% opacity
                local bpmText = string.format("BPM %.0f",
                                              signalProcessor.getClockBPM())
                local smallFont = love.graphics.newFont(10) -- Smaller font
                local prevFont = love.graphics.getFont()
                love.graphics.setFont(smallFont)
                local textWidth = smallFont:getWidth(bpmText)
                local buttonWidth = 16
                local buttonHeight = 16
                local buttonPadding = 8

                -- Get positions of inputs 9-12 (bottom row)
                local inputPos = io_panel.getPhysicalInputPositions()
                local centerX, textY

                if inputPos and #inputPos >= 12 then
                    -- Calculate center between input 9 and input 12
                    local leftX = inputPos[9][1]
                    local rightX = inputPos[12][1]
                    centerX = (leftX + rightX) / 2 - textWidth / 2

                    -- Calculate Y position with 16px gap under bottom row
                    local bottomY = inputPos[9][2] + 15 -- Radius of input circle
                    textY = bottomY + 16 -- 16px gap below the bottom of the circles
                else
                    -- Fallback if positions not available
                    local cellWidth = 40 -- Width of each input cell
                    local inputSectionWidth = 4 * cellWidth
                    local inputCenterX = 40 + (inputSectionWidth / 2) -- 40 is physInputX
                    centerX = inputCenterX - textWidth / 2
                    textY = physicalIOBottomY + 16
                end

                -- Calculate button positions
                local minusButtonX = centerX - buttonWidth - buttonPadding
                local plusButtonX = centerX + textWidth + buttonPadding

                -- Store BPM button positions for click detection
                io_panel.setBPMButtonPositions({
                    minus = {
                        x = minusButtonX,
                        y = textY - 2,
                        width = buttonWidth,
                        height = buttonHeight
                    },
                    plus = {
                        x = plusButtonX,
                        y = textY - 2,
                        width = buttonWidth,
                        height = buttonHeight
                    }
                })

                -- Draw minus button
                love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
                love.graphics.rectangle("fill", minusButtonX, textY - 2,
                                        buttonWidth, buttonHeight, 3, 3)
                love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(minusButtonX + 3,
                                   textY + buttonHeight / 2 - 2,
                                   minusButtonX + buttonWidth - 3,
                                   textY + buttonHeight / 2 - 2)

                -- Draw BPM text
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.print(bpmText, centerX, textY)

                -- Draw plus button
                love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
                love.graphics.rectangle("fill", plusButtonX, textY - 2,
                                        buttonWidth, buttonHeight, 3, 3)
                love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
                love.graphics.line(plusButtonX + 3,
                                   textY + buttonHeight / 2 - 2,
                                   plusButtonX + buttonWidth - 3,
                                   textY + buttonHeight / 2 - 2)
                love.graphics.line(plusButtonX + buttonWidth / 2, textY + 3 - 2,
                                   plusButtonX + buttonWidth / 2,
                                   textY + buttonHeight - 3 - 2)

                love.graphics.setFont(prevFont) -- Restore previous font
            end

            -- Draw Parameter Knobs
            parameter_knobs.draw({
                scriptParameters = parameterManager.getParameters(),
                displayWidth = display.getConfig().width,
                panelY = physicalIOBottomY + 24, -- Position 24px below physical I/O section
                knobRadius = 12,
                knobSpacing = 80,
                parameterAutomation = parameterManager.getParameterAutomation(),
                uiScaleFactor = windowManager.getUIScaleFactor()
            })
        end

        -- Draw dragging line if needed
        local dragState = inputHandler.getDraggingState()
        if dragState.dragging then
            love.graphics.setColor(1, 1, 0)
            local srcX, srcY = 0, 0
            if dragState.dragType == "input" then
                local pos = io_panel.getInputPosition(dragState.dragIndex)
                if pos then srcX, srcY = pos[1], pos[2] end
            elseif dragState.dragType == "output" then
                local pos = io_panel.getOutputPosition(dragState.dragIndex)
                if pos then srcX, srcY = pos[1], pos[2] end
            end
            love.graphics.line(srcX, srcY, dragState.dragX, dragState.dragY)
        end

        -- Draw hot reload indicator LED directly on screen
        local reloadState = scriptManager.getReloadState()
        if reloadState.enableAutoReload then
            if reloadState.reloadBlink and math.floor(time * 4) % 2 == 0 then
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

        -- Draw notifications
        notifications.draw(fontDefault, fontSmall)
    end
end

function M.keypressed(key)
    -- F1 toggles minimal mode
    if key == "f1" then
        local isMinimal = windowManager.isMinimalMode()

        -- First toggle the UI state in the MinimalMode module
        if isMinimal then
            MinimalMode.deactivate()
        else
            MinimalMode.activate()
        end

        -- Then update the window manager state
        windowManager.setMinimalMode(not isMinimal)
        saveIOState()
        return
    end

    -- Handle key in minimal mode if active
    if windowManager.isMinimalMode() then
        if MinimalMode.keypressed(key) then
            return -- Key was handled by minimal mode
        end
    end

    -- Continue with normal key handling
    if key == "space" then
        -- Only toggle overlays when not in minimal mode
        if not windowManager.isMinimalMode() then
            windowManager.toggleOverlay()
        end
        return
    end

    if key == "r" and love.keyboard.isDown("lctrl") then
        -- Ctrl+R: Force script reload
        print("Manual reload triggered...")

        -- Save window position before making any changes
        local windowX, windowY = love.window.getPosition()

        -- Save current I/O mappings before reload
        saveIOState()

        -- Trigger a reload
        local success, newScript, newScriptParameters =
            scriptManager.reloadScript(createDefaultMappings,
                                       scriptInputAssignments,
                                       scriptOutputAssignments)

        if success then
            -- Store previous I/O connections
            local prevInputAssignments = scriptInputAssignments
            local prevOutputAssignments = scriptOutputAssignments

            -- Update script and parameters
            script = newScript
            scriptParameters = newScriptParameters

            -- Update parameter manager
            parameterManager.setParameters(scriptParameters, script)

            -- Recalculate I/O counts
            scriptInputCount, scriptOutputCount =
                scriptManager.getScriptIOCounts()

            -- Restore previous I/O connections where possible
            scriptInputAssignments = {}
            scriptOutputAssignments = {}

            for i = 1, scriptInputCount do
                scriptInputAssignments[i] = prevInputAssignments[i]
            end

            for i = 1, scriptOutputCount do
                scriptOutputAssignments[i] = prevOutputAssignments[i]
            end

            -- Reset outputs that are no longer connected
            signalProcessor.resetUnconnectedOutputs(scriptOutputAssignments)

            -- Resize window to fit content (but don't change the overlay mode)
            windowManager.resizeWindow()

            -- Always restore window position after resize
            love.window.setPosition(windowX, windowY)

            print("Script manually reloaded successfully!")
        end
        return
    elseif key == "h" and love.keyboard.isDown("lctrl") then
        -- Ctrl+H: Toggle hot reload
        scriptManager.toggleAutoReload()
        local enabled = scriptManager.getReloadState().enableAutoReload
        print("Hot reload:", enabled and "enabled" or "disabled")
        return
    elseif key == "o" and love.keyboard.isDown("lctrl") then
        -- Ctrl+O: Toggle OSC
        osc_client.toggle()
        return
    elseif key == "d" and love.keyboard.isDown("lctrl") then
        -- Ctrl+D: Toggle debug mode
        uiState.toggleDebugMode()
        print("Debug mode:", uiState.isDebugMode() and "enabled" or "disabled")
        return
    elseif key == "s" and love.keyboard.isDown("lctrl") then
        -- Ctrl+S: Save current I/O mappings
        markMappingsChanged() -- Mark as changed to force save
        saveIOState(true) -- Force save
        print("I/O mappings manually saved to " .. stateFile)
        return
    end
end

function M.keyreleased(key)
    -- Let minimal mode handle if active
    if windowManager.isMinimalMode() then MinimalMode.keyreleased(key) end
end

function M.mousepressed(x, y, button)
    return inputHandler.mousepressed(x, y, button)
end

function M.mousemoved(x, y, dx, dy) return inputHandler.mousemoved(x, y, dx, dy) end

function M.mousereleased(x, y, button)
    return inputHandler.mousereleased(x, y, button)
end

function M.wheelmoved(x, y) return inputHandler.wheelmoved(x, y) end

function M.quit()
    -- Force save IO mappings regardless of whether they've changed
    markMappingsChanged() -- Mark as changed to force save
    saveIOState(true) -- Pass true to force a save

    -- Clean up OSC client
    osc_client.cleanup()

    print("Emulator state saved successfully before closing")
end

-- Accessor for debug mode
function M.isDebugMode() return uiState.isDebugMode() end

-- Public function to load a script from a path
function M.loadScriptFromPath(filePath)
    if not filePath then return end

    print("Loading script from path:", filePath)

    -- Save window position before making any changes
    local windowX, windowY = love.window.getPosition()

    -- Update scriptPath and load the script
    scriptPath = filePath
    scriptManager.setScriptPath(filePath)

    -- Update state.json with the script path
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

        -- Update parameter manager
        parameterManager.setParameters(scriptParameters, script)

        -- Determine input/output counts
        scriptInputCount, scriptOutputCount = scriptManager.getScriptIOCounts()

        -- Clear existing assignments
        for i = 1, scriptInputCount do scriptInputAssignments[i] = nil end
        for i = 1, scriptOutputCount do scriptOutputAssignments[i] = nil end

        -- Create default mappings for the new script
        createDefaultMappings()

        -- Update minimal mode parameters
        MinimalMode.setParameters(scriptParameters)

        -- Update window manager with new info and resize
        windowManager.setState({
            script = script,
            scriptInputCount = scriptInputCount,
            scriptOutputCount = scriptOutputCount,
            scriptParameters = scriptParameters,
            fontSmall = fontSmall
        })

        -- Resize window for new script content
        windowManager.resizeWindow()

        -- Always restore window position after resize
        love.window.setPosition(windowX, windowY)

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
