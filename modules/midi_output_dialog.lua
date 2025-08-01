-- midi_output_dialog.lua
-- Dialog for selecting MIDI output devices
local M = {}

-- Local state
local isActive = false
local midiPorts = {}
local selectedIndex = 1
local dialogWidth = 400
local dialogHeight = 300
local dialogX = 0
local dialogY = 0
local itemHeight = 30
local scrollOffset = 0
local maxVisibleItems = 8

-- Dependencies
local midiHandler = nil

-- Initialize the dialog
function M.init(deps)
    midiHandler = deps.midiHandler
    return M
end

-- Show the dialog
function M.show()
    if not midiHandler then
        return false
    end
    
    isActive = true
    selectedIndex = 1
    scrollOffset = 0
    
    -- Get available MIDI ports
    if midiHandler.isAvailable() then
        midiPorts = midiHandler.getOutputPorts()
        -- Add "None" option at the beginning
        table.insert(midiPorts, 1, {
            index = -1,
            name = "None (Disable MIDI Output)"
        })
    else
        -- No MIDI support
        midiPorts = {{
            index = -1,
            name = "MIDI support not available"
        }}
    end
    
    -- Center dialog
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    dialogX = (screenWidth - dialogWidth) / 2
    dialogY = (screenHeight - dialogHeight) / 2
    
    -- Adjust height based on number of items
    local contentHeight = #midiPorts * itemHeight + 80 -- Extra space for title and padding
    dialogHeight = math.min(contentHeight, 400)
    maxVisibleItems = math.floor((dialogHeight - 80) / itemHeight)
    
    return true
end

-- Hide the dialog
function M.hide()
    isActive = false
end

-- Check if dialog is active
function M.isActive()
    return isActive
end

-- Update the dialog
function M.update(dt)
    -- Nothing to update currently
end

-- Draw the dialog
function M.draw()
    if not isActive then return end
    
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Dialog background
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Dialog border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    local title = "Select MIDI Output Device"
    local titleWidth = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, dialogX + (dialogWidth - titleWidth) / 2, dialogY + 10)
    
    -- Instructions
    love.graphics.setFont(love.graphics.newFont(12))
    local instructions = "Use arrow keys to select, Enter to confirm, Escape to cancel"
    local instructionsWidth = love.graphics.getFont():getWidth(instructions)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(instructions, dialogX + (dialogWidth - instructionsWidth) / 2, dialogY + 35)
    
    -- List area
    local listY = dialogY + 60
    local listHeight = dialogHeight - 80
    
    -- Set clipping rectangle for the list
    love.graphics.setScissor(dialogX, listY, dialogWidth, listHeight)
    
    -- Draw items
    for i = 1, #midiPorts do
        local itemY = listY + (i - 1 - scrollOffset) * itemHeight
        
        -- Only draw if visible
        if itemY >= listY - itemHeight and itemY < listY + listHeight then
            -- Highlight selected item
            if i == selectedIndex then
                love.graphics.setColor(0.3, 0.3, 0.6, 1)
                love.graphics.rectangle("fill", dialogX + 10, itemY, dialogWidth - 20, itemHeight - 2)
            end
            
            -- Draw port name
            love.graphics.setColor(1, 1, 1, 1)
            local port = midiPorts[i]
            local displayName = port.name
            
            -- Add current indicator
            if midiHandler.getCurrentOutputPortIndex() == port.index then
                displayName = displayName .. " (Current)"
                love.graphics.setColor(0.7, 1, 0.7, 1)
            end
            
            love.graphics.print(displayName, dialogX + 20, itemY + (itemHeight - 12) / 2)
        end
    end
    
    -- Reset scissor
    love.graphics.setScissor()
    
    -- Scrollbar if needed
    if #midiPorts > maxVisibleItems then
        local scrollbarX = dialogX + dialogWidth - 15
        local scrollbarHeight = listHeight
        local thumbHeight = math.max(20, scrollbarHeight * maxVisibleItems / #midiPorts)
        local thumbY = listY + (scrollOffset / (#midiPorts - maxVisibleItems)) * (scrollbarHeight - thumbHeight)
        
        -- Scrollbar track
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", scrollbarX, listY, 10, scrollbarHeight)
        
        -- Scrollbar thumb
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 10, thumbHeight)
    end
end

-- Handle key press
function M.keypressed(key)
    if not isActive then return false end
    
    if key == "escape" then
        M.hide()
        return true
    elseif key == "return" or key == "kpenter" then
        -- Select the current item
        local selected = midiPorts[selectedIndex]
        if selected and midiHandler.isAvailable() then
            if selected.index >= 0 then
                midiHandler.openOutputPort(selected.index)
            else
                -- "None" selected - close any open port
                midiHandler.closeOutputPort()
            end
        end
        M.hide()
        return true
    elseif key == "up" then
        selectedIndex = math.max(1, selectedIndex - 1)
        -- Adjust scroll to keep selection visible
        if selectedIndex - 1 < scrollOffset then
            scrollOffset = selectedIndex - 1
        end
        return true
    elseif key == "down" then
        selectedIndex = math.min(#midiPorts, selectedIndex + 1)
        -- Adjust scroll to keep selection visible
        if selectedIndex > scrollOffset + maxVisibleItems then
            scrollOffset = selectedIndex - maxVisibleItems
        end
        return true
    elseif key == "pageup" then
        selectedIndex = math.max(1, selectedIndex - maxVisibleItems)
        scrollOffset = math.max(0, scrollOffset - maxVisibleItems)
        return true
    elseif key == "pagedown" then
        selectedIndex = math.min(#midiPorts, selectedIndex + maxVisibleItems)
        scrollOffset = math.min(#midiPorts - maxVisibleItems, scrollOffset + maxVisibleItems)
        return true
    elseif key == "home" then
        selectedIndex = 1
        scrollOffset = 0
        return true
    elseif key == "end" then
        selectedIndex = #midiPorts
        scrollOffset = math.max(0, #midiPorts - maxVisibleItems)
        return true
    end
    
    return false
end

-- Handle mouse press
function M.mousepressed(x, y, button)
    if not isActive then return false end
    
    -- Check if click is outside dialog
    if x < dialogX or x > dialogX + dialogWidth or y < dialogY or y > dialogY + dialogHeight then
        M.hide()
        return true
    end
    
    -- Check if click is on an item
    local listY = dialogY + 60
    if y >= listY and y < dialogY + dialogHeight - 20 then
        local clickedIndex = math.floor((y - listY) / itemHeight) + scrollOffset + 1
        if clickedIndex >= 1 and clickedIndex <= #midiPorts then
            selectedIndex = clickedIndex
            -- Double-click to select
            if button == 1 then
                local selected = midiPorts[selectedIndex]
                if selected and midiHandler.isAvailable() then
                    if selected.index >= 0 then
                        midiHandler.openOutputPort(selected.index)
                    else
                        midiHandler.closeOutputPort()
                    end
                end
                M.hide()
            end
            return true
        end
    end
    
    return true -- Consume all clicks when dialog is active
end

-- Handle mouse wheel
function M.wheelmoved(x, y)
    if not isActive then return false end
    
    if #midiPorts > maxVisibleItems then
        scrollOffset = math.max(0, math.min(#midiPorts - maxVisibleItems, scrollOffset - y))
        return true
    end
    
    return false
end

-- Get selected MIDI port info
function M.getSelectedPort()
    if selectedIndex >= 1 and selectedIndex <= #midiPorts then
        return midiPorts[selectedIndex]
    end
    return nil
end

return M