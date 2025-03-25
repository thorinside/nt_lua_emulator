-- window_manager.lua
-- Module for handling window sizing and display layout in the emulator
local M = {} -- Module table

-- Local state variables
local uiScaleFactor = 1.0 -- Base scale
local displayScaleFactor = 3.0 -- Display scale factor
local hiResRenderScale = 4.0 -- High-resolution rendering scale
local displayWidth, displayHeight = 256, 64 -- Default OLED display size

-- Calculate display area dimensions based on scale factors
local scaledDisplayWidth
local scaledDisplayHeight

-- Layout positions
local scriptIOPanelY
local physicalIOStartY
local paramKnobPanelY

-- Current window dimensions
local windowWidth, windowHeight

-- Current active overlay
local activeOverlay = "io" -- "controls" or "io"

-- Minimal mode state
local minimalModeEnabled = false

-- Cached height for window calculations
local cachedIOHeight = nil

-- Function to initialize the window manager
function M.init(deps)
    -- Store dependencies
    M.display = deps.display
    M.io_panel = deps.io_panel
    M.controls = deps.controls
    M.MinimalMode = deps.MinimalMode

    -- Calculate display dimensions
    scaledDisplayWidth = displayWidth * displayScaleFactor
    scaledDisplayHeight = displayHeight * displayScaleFactor

    -- Layout positions (starting after the display area)
    scriptIOPanelY = (scaledDisplayHeight / uiScaleFactor) + 20 -- Reduced top margin
    physicalIOStartY = scriptIOPanelY -- Aligned with script I/O
    paramKnobPanelY = physicalIOStartY + 300 -- Adjusted based on physical I/O height

    return M
end

-- Set the display configuration
function M.setDisplayConfig(config)
    displayWidth = config.width or displayWidth
    displayHeight = config.height or displayHeight
    displayScaleFactor = config.scaling or displayScaleFactor

    -- Recalculate dimensions
    scaledDisplayWidth = displayWidth * displayScaleFactor
    scaledDisplayHeight = displayHeight * displayScaleFactor

    -- Update layout positions
    scriptIOPanelY = (scaledDisplayHeight / uiScaleFactor) + 20
    physicalIOStartY = scriptIOPanelY
    paramKnobPanelY = physicalIOStartY + 300
end

-- Set the minimal mode state
function M.setMinimalMode(enabled)
    minimalModeEnabled = enabled
    -- Resize window based on new state
    M.resizeWindow()
    return minimalModeEnabled
end

-- Get the minimal mode state
function M.isMinimalMode() return minimalModeEnabled end

-- Toggle the active overlay (controls/io)
function M.toggleOverlay()
    activeOverlay = (activeOverlay == "controls") and "io" or "controls"
    -- Resize window based on new overlay
    M.resizeWindow()
    return activeOverlay
end

-- Get the current active overlay
function M.getActiveOverlay() return activeOverlay end

-- Calculate window height based on content and overlay type
function M.calculateWindowHeight()
    -- In minimal mode, use display dimensions only
    if minimalModeEnabled then return scaledDisplayHeight end

    -- Calculate the height of the display area in UI coordinates
    local displayAreaHeight = scaledDisplayHeight / uiScaleFactor

    -- Add 24px margin that will be at the bottom of the window
    local bottomMargin = 24

    if activeOverlay == "controls" then
        -- For controls overlay - use the controls height function
        return displayAreaHeight + M.controls.getHeight() + bottomMargin
    else
        -- For IO overlay - use cached height if available, or calculate it
        if cachedIOHeight then
            return displayAreaHeight + cachedIOHeight + bottomMargin
        end

        -- Set up parameters for IO panel layout calculation
        local params = {
            inputCount = M.scriptInputCount or 0,
            outputCount = M.scriptOutputCount or 0,
            font = M.fontSmall,
            screenWidth = scaledDisplayWidth,
            ioY = (scaledDisplayHeight / uiScaleFactor) + 20
        }

        -- Get the height of the IO overlay components
        local scriptIOHeight = M.io_panel.getScriptIOHeight(params)
        local physicalIOHeight = M.io_panel.getPhysicalIOHeight()

        -- Calculate parameter knobs height
        local paramCount = M.scriptParameters and #M.scriptParameters or 0
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

-- Update state from emulator
function M.setState(state)
    M.script = state.script
    M.scriptInputCount = state.scriptInputCount
    M.scriptOutputCount = state.scriptOutputCount
    M.scriptParameters = state.scriptParameters
    M.fontSmall = state.fontSmall
end

-- Invalidate cached height calculations (called when script changes)
function M.invalidateCache() cachedIOHeight = nil end

-- Resize the window based on current state
function M.resizeWindow()
    -- Save current window position
    local x, y = love.window.getPosition()

    -- Calculate window dimensions
    if minimalModeEnabled then
        -- In minimal mode, only show the display area
        windowWidth = scaledDisplayWidth
        windowHeight = scaledDisplayHeight
    else
        -- Full mode shows either controls or IO panels
        windowWidth = scaledDisplayWidth
        windowHeight = M.calculateWindowHeight()
    end

    -- Apply the new window size
    love.window.setMode(windowWidth, windowHeight,
                        {resizable = false, msaa = 8, vsync = 1})

    -- Restore position
    love.window.setPosition(x, y)

    return windowWidth, windowHeight
end

-- Get scaled display dimensions
function M.getScaledDisplayDimensions()
    return scaledDisplayWidth, scaledDisplayHeight
end

-- Get UI scale factor
function M.getUIScaleFactor() return uiScaleFactor end

-- Get layout positions
function M.getLayoutPositions()
    return {
        scriptIOPanelY = scriptIOPanelY,
        physicalIOStartY = physicalIOStartY,
        paramKnobPanelY = paramKnobPanelY
    }
end

return M
