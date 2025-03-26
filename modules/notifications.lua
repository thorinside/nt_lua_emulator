-- notifications.lua
-- Module for handling notifications in the NT Lua Emulator
local M = {}

-- State for error notifications
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
function M.showNotification(message)
    notification.active = true
    notification.message = message
    notification.time = 0
    notification.targetAlpha = 1.0
    print("Info: " .. message)
end

-- Function to show error notifications
function M.showErrorNotification(message)
    errorNotification.active = true
    errorNotification.message = message
    errorNotification.time = 0
    errorNotification.targetAlpha = 1.0
    print("Error: " .. message)
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

    -- Update error notification
    if errorNotification.active then
        -- Update notification alpha for fade in/out
        errorNotification.alpha = errorNotification.alpha +
                                      (errorNotification.targetAlpha -
                                          errorNotification.alpha) * 5 * dt

        -- Update notification time
        errorNotification.time = errorNotification.time + dt
        if errorNotification.time > errorNotification.duration then
            errorNotification.targetAlpha = 0
            if errorNotification.alpha < 0.01 then
                errorNotification.active = false
            end
        end
    end
end

-- Draw notifications on screen
function M.draw(fontDefault, fontSmall)
    -- Draw error notification if active
    if errorNotification.active then
        -- Background rectangle
        love.graphics.setColor(0.1, 0.1, 0.1, errorNotification.alpha * 0.9)
        local notifWidth = 400
        local notifHeight = 80
        local notifX = (love.graphics.getWidth() - notifWidth) / 2
        local notifY = 100
        love.graphics.rectangle("fill", notifX, notifY, notifWidth, notifHeight,
                                8, 8)

        -- Border
        love.graphics.setColor(0.9, 0.2, 0.2, errorNotification.alpha * 0.9)
        love.graphics.rectangle("line", notifX, notifY, notifWidth, notifHeight,
                                8, 8)

        -- Text
        love.graphics.setColor(1, 1, 1, errorNotification.alpha)
        love.graphics.setFont(fontDefault)
        love.graphics.printf("Error", notifX + 10, notifY + 10, notifWidth - 20,
                             "center")
        love.graphics.setFont(fontSmall)
        love.graphics.printf(errorNotification.message, notifX + 10,
                             notifY + 35, notifWidth - 20, "center")
    end

    -- Draw regular notification if active
    if notification.active then
        -- Background rectangle
        love.graphics.setColor(0.1, 0.1, 0.1, notification.alpha * 0.9)
        local notifWidth = 400
        local notifHeight = 60
        local notifX = (love.graphics.getWidth() - notifWidth) / 2
        local notifY = 100
        love.graphics.rectangle("fill", notifX, notifY, notifWidth, notifHeight,
                                8, 8)

        -- Border
        love.graphics.setColor(0.3, 0.7, 0.9, notification.alpha * 0.9)
        love.graphics.rectangle("line", notifX, notifY, notifWidth, notifHeight,
                                8, 8)

        -- Text
        love.graphics.setColor(1, 1, 1, notification.alpha)
        love.graphics.setFont(fontDefault)
        love.graphics.printf(notification.message, notifX + 10, notifY + 20,
                             notifWidth - 20, "center")
    end
end

-- Return the error notification state
function M.getErrorNotificationState() return errorNotification end

-- Return the regular notification state
function M.getNotificationState() return notification end

-- Export the module
return M
