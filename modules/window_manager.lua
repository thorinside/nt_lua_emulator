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
    
    -- Physical I/O should be positioned below hardware controls, not aligned with script I/O
    local controlsHeight = 120 -- Approximate height of hardware controls section (kPotRadius * 6 from controls.lua)
    local spacingBetweenSections = 40 -- Match emulator.lua spacing
    physicalIOStartY = (scaledDisplayHeight / uiScaleFactor) + controlsHeight + spacingBetweenSections
    
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
    
    -- Physical I/O should be positioned below hardware controls, not aligned with script I/O
    local controlsHeight = 120 -- Approximate height of hardware controls section (kPotRadius * 6 from controls.lua)
    local spacingBetweenSections = 40 -- Match emulator.lua spacing
    physicalIOStartY = (scaledDisplayHeight / uiScaleFactor) + controlsHeight + spacingBetweenSections
    
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

    -- Add 16px margin that will be at the bottom of the window for parameter knobs
    local bottomMargin = 16

    -- For unified layout, calculate both controls and IO heights together
    local controlsHeight = M.controls.getHeight()
    
    -- Calculate IO height
    local ioHeight
    if cachedIOHeight then
        ioHeight = cachedIOHeight
    else
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

        -- Calculate parameter knobs height more accurately (matching parameter_knobs.lua calculation)
        local paramCount = M.scriptParameters and #M.scriptParameters or 0
        local paramKnobHeight = 0
        if paramCount > 0 then
            local knobsPerRow = 9
            local paramKnobRows = math.ceil(paramCount / knobsPerRow)
            local knobRadius = 12 * uiScaleFactor
            local knobDiameter = knobRadius * 2
            local nameHeight = 10 * uiScaleFactor
            local valueHeight = 10 * uiScaleFactor
            local autoHeight = 10 * uiScaleFactor
            local knobTotalHeight = knobDiameter + nameHeight + valueHeight + (autoHeight * 0.5)
            local rowSpacing = knobTotalHeight + 15 * uiScaleFactor
            paramKnobHeight = (paramKnobRows * rowSpacing) + 20 -- Add 20px padding
        end

        -- Total IO content height
        ioHeight = scriptIOHeight + physicalIOHeight +
                   paramKnobHeight + 24 -- 24px spacing between sections

        -- Cache the calculated height
        cachedIOHeight = ioHeight
    end

    -- For unified layout, combine both heights with spacing
    local spacingBetweenSections = 40 -- Space between controls and IO sections
    return displayAreaHeight + controlsHeight + spacingBetweenSections + ioHeight + bottomMargin
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
    -- Always remember current position before doing anything
    local currentX, currentY = love.window.getPosition()
    local currentWidth, currentHeight = love.graphics.getDimensions()

    -- Calculate window dimensions
    if minimalModeEnabled then
        -- In minimal mode, only show the display area
        windowWidth = scaledDisplayWidth
        windowHeight = scaledDisplayHeight
    else
        -- Full mode shows either controls or IO panels
        windowWidth = scaledDisplayWidth

        -- Calculate height based on content
        if M.scriptInputCount ~= nil and M.scriptOutputCount ~= nil then
            windowHeight = M.calculateWindowHeight()
        else
            -- Reasonable default if we don't have script info yet
            windowHeight = scaledDisplayHeight + 400
        end
    end

    -- Calculate percentage difference to avoid small resizes
    local widthDiff = math.abs(currentWidth - windowWidth) / windowWidth
    local heightDiff = math.abs(currentHeight - windowHeight) / windowHeight

    -- Only resize if dimensions changed by more than 5%
    -- This prevents minor adjustments that could cause jumping
    if widthDiff > 0.05 or heightDiff > 0.05 then
        -- Set new mode while preserving position
        love.window.setMode(windowWidth, windowHeight,
                            {resizable = false, msaa = 8, vsync = 1})

        -- Ensure position is restored exactly
        love.window.setPosition(currentX, currentY)
    end

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
