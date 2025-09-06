-- notifications.lua
-- Module for handling notifications in the NT Lua Emulator
local M = {}

-- State for temporary notifications
local notification = {
    active = false,
    message = "",
    time = 0,
    duration = 2, -- seconds to show notification
    targetAlpha = 0.0,
    alpha = 0.0
}

-- Error queue specific state
local errorQueue = {}
local maxErrorsDisplayed = 5
local lastErrorMessage = ""
local lastErrorTime = 0
local errorDuplicateThreshold = 0.5 -- seconds
local errorDialogPadding = 8
local errorDismissButtonSize = 12

-- Function to show notifications
function M.showNotification(newMessage)
    notification.active = true
    notification.message = newMessage
    notification.time = 0
    notification.targetAlpha = 1.0
    print("Info: " .. newMessage)
    -- Clear errors when a normal notification appears?
    -- errorQueue = {}
end

-- Function to show error notifications
function M.showErrorNotification(newMessage)
    local currentTime = love.timer.getTime()

    -- Duplicate suppression
    if newMessage == lastErrorMessage and currentTime - lastErrorTime <
        errorDuplicateThreshold then
        return -- Ignore recent duplicate
    end

    -- Stricter Duplicate Check: Is the exact message already in the queue?
    for _, existingError in ipairs(errorQueue) do
        if existingError.message == newMessage then
            return -- Don't add if already present
        end
    end

    -- Add to queue
    local errorItem = {
        message = newMessage,
        timestamp = currentTime,
        rect = nil -- Will be calculated during draw
    }
    table.insert(errorQueue, 1, errorItem) -- Insert at the beginning (top of the visual stack)
    lastErrorMessage = newMessage
    lastErrorTime = currentTime

    -- Limit queue size
    while #errorQueue > maxErrorsDisplayed do
        table.remove(errorQueue) -- Remove the oldest from the end
    end

    -- Keep the normal message mechanism for non-errors? Or remove?
    -- For now, let errors *only* use the queue.
    -- message = newMessage
    -- messageType = "error"
    -- displayEndTime = love.timer.getTime() + displayDuration * 2 -- Show errors longer?
end

-- Update notification states
function M.update(dt)
    -- Update regular notification
    if notification.active then
        -- Update notification alpha for fade in/out
        notification.alpha = notification.alpha +
                                 (notification.targetAlpha - notification.alpha) *
                                 5 * dt

        -- Update notification time
        notification.time = notification.time + dt
        if notification.time > notification.duration then
            notification.targetAlpha = 0
            if notification.alpha < 0.01 then
                notification.active = false
            end
        end
    end
end

-- Draw notifications on screen
function M.draw(fontDefault, fontSmall)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local currentTime = love.timer.getTime()

    -- 1. Draw queued error messages (persistent)
    if #errorQueue > 0 then
        local currentY = 10 -- Starting Y position for the topmost error
        local dialogW = 300 -- Fixed width for error dialogs

        for i, errorItem in ipairs(errorQueue) do
            -- Use small font for errors
            love.graphics.setFont(fontSmall)
            local fontHeight = fontSmall:getHeight()

            -- Wrap text (requires a helper function, assuming one exists or implement basic one)
            -- For now, let's just estimate height based on lines (simple split)
            local lines = {}
            for line in string.gmatch(errorItem.message, "[^\n]+") do
                -- Basic word wrap simulation (crude)
                local currentLine = ""
                for word in string.gmatch(line .. " ", "(%S+)%s*") do
                    local testLine = currentLine ..
                                         (currentLine == "" and "" or " ") ..
                                         word
                    if fontSmall:getWidth(testLine) >
                        (dialogW - errorDialogPadding * 2) then
                        table.insert(lines, currentLine)
                        currentLine = word
                    else
                        currentLine = testLine
                    end
                end
                if currentLine ~= "" then
                    table.insert(lines, currentLine)
                end
            end

            local textHeight = #lines * fontHeight
            local dialogH = textHeight + errorDialogPadding * 2 +
                                errorDismissButtonSize -- Add space for X button row
            local dialogX = screenW - dialogW - 10
            local dialogY = currentY

            -- Store the rectangle for click detection
            errorItem.rect = {
                x = dialogX,
                y = dialogY,
                w = dialogW,
                h = dialogH
            }

            -- Draw background
            love.graphics.setColor(0.6, 0.1, 0.1, 0.85) -- Dark red, semi-transparent
            love.graphics.rectangle("fill", dialogX, dialogY, dialogW, dialogH,
                                    5, 5) -- Rounded corners

            -- Draw dismiss button ('X')
            local btnX = dialogX + dialogW - errorDismissButtonSize -
                             errorDialogPadding / 2
            local btnY = dialogY + errorDialogPadding / 2
            love.graphics.setColor(0.9, 0.7, 0.7, 1) -- Lighter red/pink for button box
            love.graphics.rectangle("fill", btnX, btnY, errorDismissButtonSize,
                                    errorDismissButtonSize, 2, 2)
            love.graphics.setColor(0.1, 0.1, 0.1, 1) -- Dark text color for X
            love.graphics.setLineWidth(1.5)
            love.graphics.print("X", btnX + errorDismissButtonSize / 2 -
                                    fontSmall:getWidth("X") / 2, btnY +
                                    errorDismissButtonSize / 2 - fontHeight / 2)

            -- Draw text lines
            love.graphics.setColor(1, 1, 1, 1) -- White text
            for j, lineText in ipairs(lines) do
                love.graphics.print(lineText, dialogX + errorDialogPadding,
                                    dialogY + errorDialogPadding +
                                        errorDismissButtonSize + (j - 1) *
                                        fontHeight)
            end

            -- Update Y for next dialog
            currentY = currentY + dialogH + 10 -- Add spacing

            -- Restore font just in case
            love.graphics.setFont(fontDefault)
        end
    end

    -- 2. Draw the normal timed notification (if any)
    if notification.active then
        love.graphics.setFont(fontDefault)
        local textWidth = fontDefault:getWidth(notification.message)
        local textHeight = fontDefault:getHeight()
        local textX = (screenW - textWidth) / 2
        local textY = (screenH - textHeight) / 2
        love.graphics.setColor(1, 1, 1, notification.alpha)
        love.graphics.printf(notification.message, textX, textY, textWidth,
                             "center")
    end
end

-- Return the error notification state
function M.getErrorNotificationState() return errorNotification end

-- Return the regular notification state
function M.getNotificationState() return notification end

function M.mousepressed(x, y, button)
    if button ~= 1 then return false end -- Only handle left clicks

    -- Check if click is within the dismiss button of any error dialog
    -- Iterate backwards because visual stack is drawn top-down but stored front-to-back
    for i = #errorQueue, 1, -1 do
        local errorItem = errorQueue[i]
        if errorItem.rect then
            local r = errorItem.rect
            -- Define the dismiss button's clickable area
            local btnX =
                r.x + r.w - errorDismissButtonSize - errorDialogPadding / 2
            local btnY = r.y + errorDialogPadding / 2
            local btnW = errorDismissButtonSize
            local btnH = errorDismissButtonSize

            -- Check collision
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                -- Clicked on dismiss button
                table.remove(errorQueue, i)
                return true -- Indicate click was handled
            end
        end
    end

    return false -- Click was not handled by notifications
end

-- Clear all error notifications from the queue
function M.clearErrors()
    errorQueue = {}
    print("Debug: All error notifications cleared")
end

-- Export the module
return M
