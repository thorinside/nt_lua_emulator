-- parameter_knobs.lua
local parameter_knobs = {}
local helpers = require("modules.helpers")

function parameter_knobs.draw(params)
    local scriptParameters = params.scriptParameters
    local displayWidth = params.displayWidth
    local panelY = params.panelY
    local knobRadius = params.knobRadius
    local knobSpacing = params.knobSpacing
    local parameterAutomation = params.parameterAutomation or {}
    local uiScaleFactor = params.uiScaleFactor or 1.0

    if not scriptParameters or #scriptParameters == 0 then return end

    -- Calculate scaled panel Y for display
    local scaledPanelY = panelY * uiScaleFactor

    -- Create smaller font for labels
    local labelFont = love.graphics.newFont(10 * uiScaleFactor) -- Scale font size
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(labelFont)

    local knobsPerRow = 9 -- Increased from 5 to 9
    local totalKnobs = #scriptParameters
    local scaledKnobRadius = knobRadius * uiScaleFactor -- Scale for display
    local knobDiameter = scaledKnobRadius * 2
    local nameHeight = 10 * uiScaleFactor
    local valueHeight = 10 * uiScaleFactor
    local autoHeight = 10 * uiScaleFactor
    local maxLabelWidth = 70 * uiScaleFactor -- Maximum width for wrapped text

    -- Calculate total height required for a knob with all labels
    local knobTotalHeight = knobDiameter + nameHeight + valueHeight +
                                (autoHeight * 0.5)

    -- Increase row spacing to prevent overlap
    local rowSpacing = knobTotalHeight + 15 * uiScaleFactor

    for i, sp in ipairs(scriptParameters) do
        local row = math.floor((i - 1) / knobsPerRow)
        local col = (i - 1) % knobsPerRow

        -- Determine the number of knobs in this row (for centering the last row)
        local knobsThisRow =
            (row == math.floor((totalKnobs - 1) / knobsPerRow)) and
                (totalKnobs % knobsPerRow ~= 0 and totalKnobs % knobsPerRow or
                    knobsPerRow) or knobsPerRow

        -- Calculate starting X position to center this row in the screen
        local totalWidth = (knobsThisRow - 1) * knobSpacing * uiScaleFactor
        local startX = (love.graphics.getWidth() - totalWidth) / 2

        -- Calculate display coordinates (in screen space)
        local displayX = startX + col * knobSpacing * uiScaleFactor
        local displayY = scaledPanelY + row * rowSpacing + scaledKnobRadius

        -- Draw automation indication if this parameter is automated
        local isAutomated = parameterAutomation[i] ~= nil
        if isAutomated then
            love.graphics.setColor(0.3, 0.5, 1.0, 0.6 + 0.3 *
                                       math.sin(love.timer.getTime() * 3))
            love.graphics.circle("line", displayX, displayY,
                                 scaledKnobRadius + 3)
        end

        -- Draw the knob
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", displayX, displayY, scaledKnobRadius)

        -- Draw the knob pointer
        if sp.type ~= "enum" then
            -- For numeric parameters, use continuous rotation
            local range = sp.max - sp.min
            local normalized = (sp.current - sp.min) / range
            local angle = -math.pi / 2 + normalized * 2 * math.pi
            love.graphics.setColor(1, 1, 0)
            local pointerLen = scaledKnobRadius - 2
            love.graphics.line(displayX, displayY,
                               displayX + pointerLen * math.cos(angle),
                               displayY + pointerLen * math.sin(angle))
        else
            -- For enum parameters, use a continuous visualization 
            -- that matches the wheel behavior
            if sp.values then
                local count = #sp.values
                -- Calculate normalized position (0.0 to 1.0)
                local normalized = (sp.current - 1) / math.max(1, count - 1)
                -- Map to full rotation range
                local angle = -math.pi / 2 + normalized * 2 * math.pi
                
                love.graphics.setColor(1, 1, 0)
                local pointerLen = scaledKnobRadius - 2
                love.graphics.line(displayX, displayY,
                                  displayX + pointerLen * math.cos(angle),
                                  displayY + pointerLen * math.sin(angle))
                
                -- Draw small indicators for each enum position
                love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
                for i = 1, count do
                    local pos = (i - 1) / math.max(1, count - 1)
                    local markAngle = -math.pi / 2 + pos * 2 * math.pi
                    local innerRadius = scaledKnobRadius - 5
                    local outerRadius = scaledKnobRadius - 2
                    
                    love.graphics.line(
                        displayX + innerRadius * math.cos(markAngle),
                        displayY + innerRadius * math.sin(markAngle),
                        displayX + outerRadius * math.cos(markAngle),
                        displayY + outerRadius * math.sin(markAngle)
                    )
                end
            else
                -- Fallback for enum without values
                love.graphics.setColor(1, 0, 0) -- Red to indicate error
                local pointerLen = scaledKnobRadius - 2
                love.graphics.line(displayX, displayY, displayX + pointerLen,
                                   displayY)
            end
        end

        -- Draw parameter name above the knob with text wrapping
        love.graphics.setColor(1, 1, 1)
        local wrappedName = helpers.wrapAndEllipsizeText(sp.name, labelFont, maxLabelWidth, 2)
        local fontHeight = labelFont:getHeight()
        local totalNameHeight = #wrappedName * fontHeight
        
        -- Position name above the knob
        local nameY = displayY - scaledKnobRadius - totalNameHeight - 6 * uiScaleFactor
        
        -- Draw each line of the name centered above the knob
        for j, line in ipairs(wrappedName) do
            local lineWidth = labelFont:getWidth(line)
            love.graphics.print(line, displayX - lineWidth / 2, nameY + (j-1) * fontHeight)
        end

        -- Draw the current value below the knob
        local valStr
        if sp.type == "enum" and sp.values then
            -- For enum parameters, show the current value name
            valStr = sp.values[sp.current] or tostring(sp.current)
        elseif sp.type == "float" then
            -- For float parameters, show scaled value with appropriate precision
            if sp.scale == kBy10 then
                valStr = string.format("%.1f", sp.current / 10)
            elseif sp.scale == kBy100 then
                valStr = string.format("%.2f", sp.current / 100)
            elseif sp.scale == kBy1000 then
                valStr = string.format("%.3f", sp.current / 1000)
            else
                valStr = string.format("%.2f", sp.current)
            end
        else
            -- For integer parameters, show whole numbers
            valStr = tostring(math.floor(sp.current + 0.5))
        end
        local valWidth = labelFont:getWidth(valStr)
        love.graphics.setColor(1, 1, 0.7, 1.0)
        love.graphics.print(valStr, displayX - valWidth / 2,
                            displayY + scaledKnobRadius + 4 * uiScaleFactor)
        
        -- Show automation indicator if applicable - moved below the value
        if parameterAutomation[i] then
            love.graphics.setColor(0.3, 0.5, 1.0, 0.8)
            local autoText = "CV" .. parameterAutomation[i]
            local autoWidth = labelFont:getWidth(autoText)
            love.graphics.print(autoText, displayX - autoWidth / 2, 
                               displayY + scaledKnobRadius + 4 * uiScaleFactor + fontHeight + 2 * uiScaleFactor)
        end
    end

    -- Restore previous font
    love.graphics.setFont(prevFont)
end

function parameter_knobs.getKnobPosition(i, params)
    local scriptParameters = params.scriptParameters
    local displayWidth = params.displayWidth
    local panelY = params.panelY
    local knobRadius = params.knobRadius
    local knobSpacing = params.knobSpacing
    local uiScaleFactor = params.uiScaleFactor or 1.0 -- Default to 1.0 if not provided

    local knobsPerRow = 9 -- Match the draw function
    local totalKnobs = #scriptParameters
    local scaledKnobRadius = knobRadius * uiScaleFactor
    local knobDiameter = scaledKnobRadius * 2
    local nameHeight = 10 * uiScaleFactor
    local valueHeight = 10 * uiScaleFactor
    local autoHeight = 10 * uiScaleFactor

    -- Calculate total height required for a knob with all labels
    local knobTotalHeight = knobDiameter + nameHeight + valueHeight +
                                (autoHeight * 0.5)

    -- Increase row spacing to prevent overlap
    local rowSpacing = knobTotalHeight + 15 * uiScaleFactor

    local row = math.floor((i - 1) / knobsPerRow)
    local col = (i - 1) % knobsPerRow

    -- Determine the number of knobs in this row (for centering)
    local knobsThisRow = (row == math.floor((totalKnobs - 1) / knobsPerRow)) and
                             ((totalKnobs % knobsPerRow ~= 0 and totalKnobs %
                                 knobsPerRow) or knobsPerRow) or knobsPerRow

    -- Calculate row width based on the number of knobs in this row
    local totalWidth = (knobsThisRow - 1) * knobSpacing * uiScaleFactor

    -- Calculate the starting X position for this row to center it
    local startX = (love.graphics.getWidth() - totalWidth) / 2

    -- Calculate the X and Y coordinates in screen space
    local knobX = startX + col * knobSpacing * uiScaleFactor
    local knobY = panelY * uiScaleFactor + row * rowSpacing + scaledKnobRadius

    return knobX, knobY
end

return parameter_knobs
