-- Drawing Test Script
-- Draws rectangles of all colors to fill the screen
return {
    name = 'Drawing Test',
    author = 'AI Assistant',
    init = function(self)
        -- No specific initialization needed for this test
        return {
            -- No inputs, outputs, or parameters needed for drawing test
            inputs = 0,
            outputs = 0,
            parameters = {}
        }
    end,
    draw = function(self)
        local screenWidth = 256
        local screenHeight = 64
        local rectWidth = 8
        local rectHeight = 8
        local margin = 5
        local spacing = 5
        local numColors = 16 -- Assuming colors 0-15

        -- Calculate available drawing area inside margins
        local availableWidth = screenWidth - (2 * margin)
        local availableHeight = screenHeight - (2 * margin)

        -- Calculate total space needed per rectangle (size + spacing)
        local cellWidth = rectWidth + spacing
        local cellHeight = rectHeight + spacing

        -- Calculate how many cells fit (ensure we don't exceed available space)
        -- Formula: num * itemSize + (num - 1) * spacing <= available
        -- Simplified: num * (itemSize + spacing) - spacing <= available
        -- Or even simpler: num <= (available + spacing) / (itemSize + spacing)
        local numCols = math.floor((availableWidth + spacing) / cellWidth)
        local numRows = math.floor((availableHeight + spacing) / cellHeight)

        for row = 0, numRows - 1 do
            for col = 0, numCols - 1 do
                -- Calculate top-left corner, including margin and spacing
                local x = margin + col * cellWidth
                local y = margin + row * cellHeight
                -- Cycle through colors 0-15
                local colorIndex = (col + row * numCols) % numColors

                local x1 = x
                local y1 = y
                local x2 = x + rectWidth - 1
                local y2 = y + rectHeight - 1

                if row == 0 then
                    -- First row: Draw rectangles
                    -- drawRectangle(x1, y1, x2, y2, color)
                    drawRectangle(x1, y1, x2, y2, colorIndex)
                elseif row == 1 then
                    -- Second row: Draw circles
                    local radius = math.min(rectWidth, rectHeight) / 2
                    local cx = x + rectWidth / 2
                    local cy = y + rectHeight / 2
                    -- drawCircle(cx, cy, radius, color)
                    drawCircle(cx, cy, radius, colorIndex)
                elseif row == numRows - 1 then
                    -- Last row: Draw Box (aliased lines)
                    -- drawBox(x1, y1, x2, y2, color)
                    drawBox(x1, y1, x2, y2, colorIndex)
                else
                    -- Middle rows: Draw Smooth Box (anti-aliased lines)
                    -- drawSmoothBox(x1, y1, x2, y2, color)
                    drawSmoothBox(x1, y1, x2, y2, colorIndex)
                end
            end
        end

        return true -- Redraw the whole screen
    end
    -- No other functions needed for this basic drawing test
}
