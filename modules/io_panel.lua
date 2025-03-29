-- io_panel.lua
local io_panel = {}
local scriptInputPositions = {}
local scriptOutputPositions = {}
local physicalInputPositions = {}
local physicalOutputPositions = {}
local lastPhysicalIOBottomY = 396 -- Initialize with a default value
local bpmButtonPositions = {} -- Store BPM button positions

local helpers = require("modules.helpers")

-- Custom function to draw just the arc without radial lines
local function drawArc(x, y, r, angle1, angle2, segments)
    local i = angle1
    local j = 0
    local step = math.pi * 2 / segments

    while i < angle2 do
        j = angle2 - i < step and angle2 or i + step
        love.graphics.line(x + (math.cos(i) * r), y - (math.sin(i) * r),
                           x + (math.cos(j) * r), y - (math.sin(j) * r))
        i = j
    end
end

function io_panel.drawScriptIO(params)
    local script = params.script
    local font = params.font
    local inputCount = params.inputCount
    local outputCount = params.outputCount
    local inputAssignments = params.inputAssignments
    local outputAssignments = params.outputAssignments
    local ioY = params.ioY
    local screenWidth = params.screenWidth or love.graphics.getWidth()
    local cellH = params.cellH or 40 -- Default to 40 if not provided

    -- Create a smaller font for labels
    local labelFont = love.graphics.newFont(9) -- Smaller font for labels (reduced from 10px)

    -- Store original font to restore later
    local originalFont = love.graphics.getFont()

    -- Set to the smaller font for labels
    love.graphics.setFont(labelFont)

    -- Layout configuration
    local circleRadius = 10
    local itemsPerColumn = 6
    local rowHeight = 28 -- Reduced from 40 to create tighter spacing
    local circleTextSpacing = 12
    local columnWidth = 200 -- Width of each main column
    local titleFont = love.graphics.newFont(16)
    local titleHeight = 33 -- Space for title
    local maxTextWidth = 60 -- Maximum width for wrapped text (reduced from 120px)
    local leftScreenMargin = 16 -- Minimum margin from screen edge

    -- Calculate total width needed for all elements (three equal columns)
    local totalWidth = columnWidth * 3
    local columnGap = 40 -- Gap between columns

    -- Calculate left margin to center the entire panel
    local leftMargin = (screenWidth - (totalWidth + columnGap * 2)) / 2

    -- Pre-calculate all names and wrap them
    local inputNames = {}
    local outputNames = {}
    local wrappedInputNames = {}
    local wrappedOutputNames = {}
    local fontHeight = labelFont:getHeight() -- Use smaller font height

    -- Calculate the maximum width needed for input labels
    local maxInputWidth = 0
    for i = 1, inputCount do
        inputNames[i] = helpers.getInputName(script, i)
        wrappedInputNames[i] = helpers.wrapAndEllipsizeText(inputNames[i],
                                                            labelFont,
                                                            maxTextWidth, 2)
        -- Calculate maximum width needed for this input's lines
        for _, line in ipairs(wrappedInputNames[i]) do
            maxInputWidth = math.max(maxInputWidth, labelFont:getWidth(line))
        end
    end

    -- Calculate the minimum x position for circles to maintain left margin
    local minCircleX = leftScreenMargin + maxInputWidth + circleTextSpacing +
                           circleRadius

    for i = 1, outputCount do
        outputNames[i] = helpers.getOutputName(script, i)
        wrappedOutputNames[i] = helpers.wrapAndEllipsizeText(outputNames[i],
                                                             labelFont,
                                                             maxTextWidth, 2)
    end

    -- Draw Script Inputs title - centered in left third of window
    love.graphics.setFont(titleFont)
    local inputTitle = "Script Inputs"
    local inputTitleWidth = titleFont:getWidth(inputTitle)
    local leftThirdWidth = (screenWidth - columnWidth - columnGap * 2) / 2 -- Width of left third
    local inputTitleX = leftThirdWidth / 2 - inputTitleWidth / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(inputTitle, inputTitleX, ioY)

    -- Draw Script Outputs title - centered in right section
    local outputTitle = "Script Outputs"
    local outputTitleWidth = titleFont:getWidth(outputTitle)

    -- Calculate the right section's width and position
    local physicalIOWidth = 4 * cellH + circleRadius * 2 + 2 * cellH -- 4 cols inputs + gap + 2 cols outputs
    local centerColumnX = (screenWidth - columnWidth) / 2
    local physicalIOEndX = centerColumnX + (columnWidth + physicalIOWidth) / 2
    local rightSectionWidth = screenWidth - physicalIOEndX
    local outputTitleX =
        physicalIOEndX + (rightSectionWidth - outputTitleWidth) / 2

    love.graphics.print(outputTitle, outputTitleX, ioY)

    -- Reset to normal font
    love.graphics.setFont(originalFont)

    -- Reset to smaller font for labels before drawing script IO elements
    love.graphics.setFont(labelFont)

    -- Adjust Y position for the actual I/O elements to account for title
    local elementsY = ioY + titleHeight

    -- Draw Script Inputs (Left Column)
    scriptInputPositions = {}
    local inputStartX = minCircleX -- Position circles after the longest text

    -- Calculate if we need two columns based on height
    local physicalIOHeight = 3 * cellH -- Height of physical I/O section (3 rows)
    local maxInputsInOneColumn = math.floor(physicalIOHeight / rowHeight)
    local useSecondColumn = inputCount > maxInputsInOneColumn

    for i = 1, inputCount do
        local row, col
        if useSecondColumn then
            row = (i - 1) % itemsPerColumn
            col = math.floor((i - 1) / itemsPerColumn)
        else
            row = i - 1
            col = 0
        end

        local cx = inputStartX + (col * columnWidth / 2)
        local cy = elementsY + (row * rowHeight) + circleRadius + fontHeight / 2
        scriptInputPositions[i] = {cx, cy}

        -- Draw wrapped text lines
        local lines = wrappedInputNames[i]
        local lineCount = #lines
        -- Adjust vertical positioning based on line count
        local textY
        if lineCount == 1 then
            -- Center single line vertically with the circle with 1px offset
            textY = cy - fontHeight / 2 - 1
        else
            -- Center multiple lines as a block with 1px offset
            textY = cy - (lineCount * fontHeight) / 2 - 1
        end

        for j, line in ipairs(lines) do
            local x = cx - circleTextSpacing - circleRadius -
                          labelFont:getWidth(line)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(line, x, textY + (j - 1) * fontHeight)
        end

        -- Draw circle
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.circle("line", cx, cy, circleRadius)

        -- Draw assignment if present
        if inputAssignments[i] then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", cx, cy, circleRadius - 2)

            love.graphics.setColor(0, 0, 0)
            local label = tostring(inputAssignments[i])
            local lw = labelFont:getWidth(label)
            love.graphics.print(label, cx - lw / 2, cy - fontHeight / 2)

            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", cx, cy, circleRadius)
        end
    end

    -- Draw Script Outputs (Right Column)
    scriptOutputPositions = {}
    local outputStartX = physicalIOEndX + 87 -- Start outputs with offset from physical I/O section

    -- Calculate if we need two columns for outputs
    local useSecondColumnOutputs = outputCount > maxInputsInOneColumn

    for i = 1, outputCount do
        local row, col
        if useSecondColumnOutputs then
            row = (i - 1) % itemsPerColumn
            col = math.floor((i - 1) / itemsPerColumn)
        else
            row = i - 1
            col = 0
        end

        local cx = outputStartX + (col * columnWidth / 2)
        local cy = elementsY + (row * rowHeight) + circleRadius + fontHeight / 2
        scriptOutputPositions[i] = {cx, cy}

        -- Draw wrapped text lines
        local lines = wrappedOutputNames[i]
        local lineCount = #lines
        -- Adjust vertical positioning based on line count
        local textY
        if lineCount == 1 then
            -- Center single line vertically with the circle with 1px offset
            textY = cy - fontHeight / 2 - 1
        else
            -- Center multiple lines as a block with 1px offset
            textY = cy - (lineCount * fontHeight) / 2 - 1
        end

        for j, line in ipairs(lines) do
            local x = cx - circleTextSpacing - circleRadius -
                          labelFont:getWidth(line)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(line, x, textY + (j - 1) * fontHeight)
        end

        -- Draw circle
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.circle("line", cx, cy, circleRadius)

        -- Draw assignment if present
        if outputAssignments[i] then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", cx, cy, circleRadius - 2)

            love.graphics.setColor(0, 0, 0)
            local label = tostring(outputAssignments[i])
            local lw = labelFont:getWidth(label)
            love.graphics.print(label, cx - lw / 2, cy - fontHeight / 2)

            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", cx, cy, circleRadius)
        end
    end

    -- Restore original font when done with IO panel
    love.graphics.setFont(originalFont)

    return elementsY -- Return the Y position where elements start (after title)
end

function io_panel.drawPhysicalIO(params)
    -- Extract parameters
    local currentInputs = params.currentInputs
    local currentOutputs = params.currentOutputs
    local inputClock = params.inputClock
    local inputPolarity = params.inputPolarity
    local inputScaling = params.inputScaling
    local clockBPM = params.clockBPM or 110
    local font = params.font
    local physInputY = params.physInputY
    local cellW = params.cellW
    local cellH = params.cellH
    local screenWidth = params.screenWidth or love.graphics.getWidth()

    -- Calculate physical I/O layout for center column
    local circleRadius = 15
    local columnWidth = 200 -- Match the script I/O column width
    local columnGap = 40

    -- Center column starts after first column plus gap
    local centerColumnX = (screenWidth - columnWidth) / 2

    -- Calculate physical I/O layout
    local gapWidth = 24 -- Fixed 24px gap between inputs and outputs
    local inputWidth = 4 * cellW -- 4 columns for inputs
    local outputWidth = 2 * cellW -- 2 columns for outputs
    local totalIOWidth = inputWidth + outputWidth + gapWidth

    -- Center the physical I/O section within the center column
    local physInputX = centerColumnX + (columnWidth - totalIOWidth) / 2
    local physOutputX = physInputX + inputWidth + gapWidth

    love.graphics.setFont(font)

    -- Draw Physical Inputs (12 inputs in 4x3 grid)
    physicalInputPositions = {}
    for row = 0, 2 do
        for col = 0, 3 do
            local idx = row * 4 + col + 1
            local cx = physInputX + col * cellW + cellW / 2
            local cy = physInputY + row * cellH + cellH / 2
            physicalInputPositions[idx] = {cx, cy}
            local v = currentInputs[idx] or 0

            if inputScaling and inputScaling[idx] ~= 1.0 then
                v = v * inputScaling[idx]
            end

            local r, g, b = helpers.voltageToColor(v)
            love.graphics.setColor(r, g, b)
            love.graphics.circle("fill", cx, cy, circleRadius)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", cx, cy, circleRadius)

            if inputScaling and inputScaling[idx] ~= 1.0 then
                -- Draw a blue arc inside the circle to represent scaling
                -- Calculate the arc angle based on the scaling factor (0 to 2*pi)
                -- Rotate by 180 degrees (start at bottom/6 o'clock position)
                local startAngle = math.pi / 2 -- Start at bottom (6 o'clock position)
                local endAngle = startAngle + (2 * math.pi * inputScaling[idx])

                -- Draw the blue arc with a slightly smaller radius than the main circle
                local arcRadius = circleRadius - 3
                love.graphics.setColor(0.2, 0.4, 1.0, 0.9)
                love.graphics.setLineWidth(2)

                -- Use the custom drawArc function to draw just the curved part
                drawArc(cx, cy, arcRadius, startAngle, endAngle, 32)

                -- Reset line width back to default
                love.graphics.setLineWidth(1)

                -- Reset color to white for the label text
                love.graphics.setColor(1, 1, 1)
            end

            local label = tostring(idx)
            local fw = font:getWidth(label)
            local fh = font:getHeight()
            love.graphics.print(label, cx - fw / 2, cy - fh / 2)

            if inputClock[idx] then
                love.graphics.setColor(1, 1, 0)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, circleRadius + 3)
                love.graphics.setLineWidth(1)
            elseif inputPolarity and inputPolarity[idx] == kUnipolar then
                love.graphics.setColor(1, 0, 0)
                love.graphics.circle("line", cx, cy, circleRadius + 3)
            end
        end
    end

    -- Draw Physical Outputs (8 outputs in 2x4 grid)
    physicalOutputPositions = {}
    for row = 0, 3 do
        for col = 0, 1 do
            local idx = row * 2 + col + 1
            local cx = physOutputX + col * cellW + cellW / 2
            local cy = physInputY + row * cellH + cellH / 2
            physicalOutputPositions[idx] = {cx, cy}
            local v = currentOutputs[idx] or 0

            local r, g, b = helpers.voltageToColor(v)
            love.graphics.setColor(r, g, b)
            love.graphics.circle("fill", cx, cy, circleRadius)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", cx, cy, circleRadius)

            local label = tostring(idx)
            local fw = font:getWidth(label)
            local fh = font:getHeight()
            love.graphics.print(label, cx - fw / 2, cy - fh / 2)
        end
    end

    -- Return the bottom Y position of the physical I/O section (using outputs height since it's taller)
    return physInputY + 4 * cellH -- Changed from 3 to 4 to account for outputs being 4 rows tall
end

-- Getter functions for drag operations:
function io_panel.getInputPosition(index) return physicalInputPositions[index] end

function io_panel.getOutputPosition(index) return physicalOutputPositions[index] end

function io_panel.getPhysicalInputPositions() return physicalInputPositions end
function io_panel.getPhysicalOutputPositions() return physicalOutputPositions end
function io_panel.getScriptInputPositions() return scriptInputPositions end
function io_panel.getScriptOutputPositions() return scriptOutputPositions end

-- Get the height of the Script IO panel based on input/output counts
function io_panel.getScriptIOHeight(params)
    local inputCount = params.inputCount or 0
    local outputCount = params.outputCount or 0
    local titleHeight = 33 -- Space for title (matches drawScriptIO)
    local rowHeight = 28 -- Matches drawScriptIO
    local itemsPerColumn = 6 -- Changed from 4 to 6

    -- Calculate number of rows needed for inputs and outputs
    local inputRows = math.ceil(inputCount / itemsPerColumn)
    local outputRows = math.ceil(outputCount / itemsPerColumn)

    -- Use the taller of the two sections
    local maxRows = math.max(inputRows, outputRows)

    -- Total height is title + rows
    return titleHeight + (maxRows * rowHeight)
end

-- Get the height of the Physical IO panel
function io_panel.getPhysicalIOHeight()
    local cellH = 40 -- Default cell height used in drawPhysicalIO
    local numRows = 4 -- Physical outputs use 4 rows

    return numRows * cellH
end

-- Add function to get the last physical IO bottom Y position
function io_panel.getLastPhysicalIOBottomY() return lastPhysicalIOBottomY end

-- Add function to set the last physical IO bottom Y position
function io_panel.setLastPhysicalIOBottomY(y) lastPhysicalIOBottomY = y end

-- Store BPM button positions for click detection
function io_panel.setBPMButtonPositions(positions) bpmButtonPositions =
    positions end

-- Get BPM button positions for click detection
function io_panel.getBPMButtonPositions() return bpmButtonPositions end

-- Add function to access the BPM for display
function io_panel.drawClockBPM(x, y, bpm, font)
    if not font then return end

    love.graphics.setColor(1, 1, 0.5) -- Light yellow
    love.graphics.print(string.format("Clock: %.1f BPM", bpm), x, y)
    love.graphics.setColor(1, 1, 1) -- Reset color
end

return io_panel
