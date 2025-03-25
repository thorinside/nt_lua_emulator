-- parameter_knobs.lua
local parameter_knobs = {}

function parameter_knobs.draw(params)
    local scriptParameters = params.scriptParameters
    local displayWidth = params.displayWidth
    local panelY = params.panelY
    local knobRadius = params.knobRadius
    local knobSpacing = params.knobSpacing
    local parameterAutomation = params.parameterAutomation or {}

    if not scriptParameters or #scriptParameters == 0 then return end

    -- Create smaller font for labels
    local labelFont = love.graphics.newFont(10) -- 2px smaller than before
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(labelFont)

    local knobsPerRow = 9 -- Increased from 5 to 9
    local totalKnobs = #scriptParameters
    local knobDiameter = knobRadius * 2
    local nameHeight = 10 -- Reduced from 12 to 10 for smaller labels
    local valueHeight = 10
    local autoHeight = 10

    -- Calculate total height required for a knob with all labels
    local knobTotalHeight = knobDiameter + nameHeight + valueHeight +
                                (autoHeight * 0.5)

    -- Increase row spacing to prevent overlap
    local rowSpacing = knobTotalHeight + 15

    for i, sp in ipairs(scriptParameters) do
        local row = math.floor((i - 1) / knobsPerRow)
        local col = (i - 1) % knobsPerRow

        -- Determine the number of knobs in this row (for centering the last row)
        local knobsThisRow =
            (row == math.floor((totalKnobs - 1) / knobsPerRow)) and
                (totalKnobs % knobsPerRow ~= 0 and totalKnobs % knobsPerRow or
                    knobsPerRow) or knobsPerRow

        -- Calculate starting X position to center this row in the screen
        local totalWidth = (knobsThisRow - 1) * knobSpacing
        local startX = (love.graphics.getWidth() - totalWidth) / 2

        local knobX = startX + col * knobSpacing
        local knobY = panelY + row * rowSpacing + knobRadius

        -- Draw automation indication if this parameter is automated
        local isAutomated = parameterAutomation[i] ~= nil
        if isAutomated then
            love.graphics.setColor(0.3, 0.5, 1.0, 0.6 + 0.3 *
                                       math.sin(love.timer.getTime() * 3))
            love.graphics.circle("line", knobX, knobY, knobRadius + 3)
        end

        -- Draw the knob
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", knobX, knobY, knobRadius)

        -- Draw the knob pointer
        if sp.type ~= "enum" then
            -- For numeric parameters, use continuous rotation
            local range = sp.max - sp.min
            local normalized = (sp.current - sp.min) / range
            local angle = -math.pi / 2 + normalized * 2 * math.pi
            love.graphics.setColor(1, 1, 0)
            local pointerLen = knobRadius - 2
            love.graphics.line(knobX, knobY,
                               knobX + pointerLen * math.cos(angle),
                               knobY + pointerLen * math.sin(angle))
        else
            -- For enum parameters, use discrete positions
            if sp.values then
                local count = #sp.values
                local sliceAngle = (2 * math.pi) / count
                local angle = -math.pi / 2 + (sp.current - 1) * sliceAngle
                love.graphics.setColor(1, 1, 0)
                local pointerLen = knobRadius - 2
                love.graphics.line(knobX, knobY,
                                   knobX + pointerLen * math.cos(angle),
                                   knobY + pointerLen * math.sin(angle))
            else
                -- Fallback for enum without values
                love.graphics.setColor(1, 0, 0) -- Red to indicate error
                local pointerLen = knobRadius - 2
                love.graphics.line(knobX, knobY, knobX + pointerLen, knobY)
            end
        end

        -- Draw parameter name above the knob
        local nameWidth = labelFont:getWidth(sp.name)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(sp.name, knobX - nameWidth / 2,
                            knobY - knobRadius - 16)

        -- Show automation indicator if applicable
        if parameterAutomation[i] then
            love.graphics.setColor(0.3, 0.5, 1.0, 0.8)
            local autoText = "CV" .. parameterAutomation[i]
            local autoWidth = labelFont:getWidth(autoText)
            love.graphics.print(autoText, knobX - autoWidth / 2,
                                knobY - knobRadius - 28)
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
        love.graphics
            .print(valStr, knobX - valWidth / 2, knobY + knobRadius + 4)
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
    local knobDiameter = knobRadius * 2
    local nameHeight = 10 -- Match the draw function
    local valueHeight = 10
    local autoHeight = 10

    -- Calculate total height required for a knob with all labels
    local knobTotalHeight = knobDiameter + nameHeight + valueHeight +
                                (autoHeight * 0.5)

    -- Increase row spacing to prevent overlap
    local rowSpacing = knobTotalHeight + 15

    local row = math.floor((i - 1) / knobsPerRow)
    local col = (i - 1) % knobsPerRow

    local knobsThisRow = (row == math.floor((totalKnobs - 1) / knobsPerRow)) and
                             ((totalKnobs % knobsPerRow ~= 0 and totalKnobs %
                                 knobsPerRow) or knobsPerRow) or knobsPerRow

    local totalWidth = (knobsThisRow - 1) * knobSpacing
    -- Make sure to correctly use the actual window width, not a scaled value
    local startX = (love.graphics.getWidth() / uiScaleFactor - totalWidth) / 2

    local knobX = startX + col * knobSpacing
    local knobY = panelY + row * rowSpacing + knobRadius

    -- Debug output to help troubleshoot
    if i <= 3 then -- Only print for first few knobs to avoid spam
        print(string.format(
                  "Knob %d position: (%.1f, %.1f), window width: %d, scale: %.1f",
                  i, knobX, knobY, love.graphics.getWidth(), uiScaleFactor))
    end

    return knobX, knobY
end

return parameter_knobs
