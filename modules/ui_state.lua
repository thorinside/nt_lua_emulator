-- ui_state.lua
-- Module for handling UI state, transitions, and visual effects
local M = {} -- Module table

-- UI state variables
local fadeAlpha = 0.0
local fadeTarget = 1.0
local fadeSpeed = 2.0 -- Adjust for faster or slower fade

-- Debugging
local debugMode = false

-- Initialize the UI state manager
function M.init(deps)
    -- Reset state
    fadeAlpha = 0.0
    fadeTarget = 1.0

    return M
end

-- Update transition effects
function M.update(dt)
    -- Update fade transition
    if fadeAlpha ~= fadeTarget then
        fadeAlpha = fadeAlpha + (fadeTarget - fadeAlpha) * fadeSpeed * dt
        -- Stop when very close to target
        if math.abs(fadeAlpha - fadeTarget) < 0.01 then
            fadeAlpha = fadeTarget
        end
    end
end

-- Get fade alpha value
function M.getFadeAlpha() return fadeAlpha end

-- Set fade target (0.0 = fully transparent, 1.0 = fully opaque)
function M.setFadeTarget(target)
    fadeTarget = math.max(0.0, math.min(1.0, target))
    return fadeTarget
end

-- Fade in (become opaque)
function M.fadeIn() fadeTarget = 1.0 end

-- Fade out (become transparent)
function M.fadeOut() fadeTarget = 0.0 end

-- Is the fade transition complete?
function M.isFadeComplete() return math.abs(fadeAlpha - fadeTarget) < 0.01 end

-- Toggle debug mode
function M.toggleDebugMode()
    debugMode = not debugMode
    return debugMode
end

-- Get debug mode state
function M.isDebugMode() return debugMode end

-- Set debug mode state
function M.setDebugMode(enabled)
    debugMode = enabled
    return debugMode
end

return M
