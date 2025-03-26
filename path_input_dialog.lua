-- path_input_dialog.lua
-- A simple path input dialog with tab completion
local PathInputDialog = {}
local json = require("lib.dkjson")

-- State
local isOpen = false
local inputText = ""
local cursorPosition = 0
local callback = nil
local completions = {}
local selectedCompletion = 1
local blinkTimer = 0
local showCursor = true
local completionsScrollPosition = 0
local repeatDelay = 0.5 -- Initial delay before repeat kicks in
local repeatInterval = 0.05 -- Time between repeat events once active
local repeatTimer = 0 -- Timer for current repeat
local lastKeyPressed = nil -- Last key that was pressed
local isRepeating = false -- Whether we're currently in repeat mode

-- Colors and dimensions
local bgColor = {0.1, 0.1, 0.1, 0.95}
local fgColor = {1, 1, 1, 1}
local borderColor = {0.5, 0.5, 0.5, 1}
local completionColor = {0.2, 0.2, 0.2, 0.9}
local selectedCompletionColor = {0.3, 0.6, 0.9, 0.6}
local width = 600
local height = 80
local completionHeight = 25
local font = nil

-- Initialize the module
function PathInputDialog.init()
    -- Initialize font
    font = love.graphics.newFont(14)
end

-- Open the dialog
function PathInputDialog.open(onPathSelected)
    if isOpen then return end

    -- Store callback
    callback = onPathSelected

    -- Get the current script path from state.json
    local stateFile = io.open("state.json", "r")
    local initialPath = ""
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()
        local success, result = pcall(json.decode, content)
        if success and result.scriptPath then
            initialPath = result.scriptPath
        end
    end

    -- Set the input text
    inputText = initialPath
    cursorPosition = #inputText

    -- Reset completions
    completions = {}
    selectedCompletion = 1

    isOpen = true
end

-- Get path completions for the current input
local function updateCompletions()
    completions = {}

    -- Get the base path and partial name
    local basePath, partialName = "", ""
    local lastSlash = inputText:match(".*/()")

    if lastSlash then
        basePath = inputText:sub(1, lastSlash - 1)
        partialName = inputText:sub(lastSlash)
    else
        -- No slash, assume it's just a filename in current directory
        basePath = "."
        partialName = inputText
    end

    -- Remove leading slash from partial name
    if partialName:sub(1, 1) == "/" then partialName = partialName:sub(2) end

    -- Use io.popen to list files that match the partial name
    local cmd = 'ls -a "' .. basePath .. '" 2>/dev/null'
    local handle = io.popen(cmd)

    if handle then
        for line in handle:lines() do
            -- Skip . and .. if we're at the start of input
            if (line ~= "." and line ~= "..") or partialName ~= "" then
                -- Check if it matches the partial name
                if partialName == "" or line:sub(1, #partialName) == partialName then
                    -- Check if it's a directory
                    local isDir = false
                    local dirCheck = io.popen(
                                         'test -d "' .. basePath .. '/' .. line ..
                                             '" && echo "true" || echo "false"')
                    if dirCheck then
                        local result = dirCheck:read("*l")
                        isDir = (result == "true")
                        dirCheck:close()
                    end

                    -- Add slash to directories
                    local displayName = line
                    if isDir then displayName = line .. "/" end

                    -- Determine full path for this completion
                    local fullPath = ""
                    if basePath == "." then
                        fullPath = displayName
                    elseif basePath:sub(-1) == "/" then
                        fullPath = basePath .. displayName
                    else
                        fullPath = basePath .. "/" .. displayName
                    end

                    table.insert(completions, {
                        displayName = displayName,
                        fullPath = fullPath,
                        isDirectory = isDir
                    })
                end
            end
        end
        handle:close()
    end

    -- Sort completions: directories first, then files
    table.sort(completions, function(a, b)
        if a.isDirectory and not b.isDirectory then
            return true
        elseif not a.isDirectory and b.isDirectory then
            return false
        else
            return a.displayName < b.displayName
        end
    end)

    -- Reset selection and scroll position
    selectedCompletion = math.min(1, #completions)
    completionsScrollPosition = 0
end

-- Convert a relative path to an absolute path
local function toAbsolutePath(path)
    -- If the path is already absolute, return it as is
    if path:sub(1, 1) == "/" then return path end

    -- Otherwise, get the current working directory and join with the path
    local currentDir = love.filesystem.getWorkingDirectory()

    -- Handle ".." properly by resolving the path
    local segments = {}
    for segment in (currentDir .. "/" .. path):gmatch("[^/]+") do
        if segment == ".." then
            table.remove(segments) -- Go up one directory
        elseif segment ~= "." then
            table.insert(segments, segment) -- Add segment to path
        end
    end

    -- Join the segments to form the absolute path
    local absolutePath = "/" .. table.concat(segments, "/")
    return absolutePath
end

-- Validate that file exists
local function validatePath(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Ensure the selected completion is visible
local function ensureSelectedVisible(visibleRows)
    if #completions == 0 or not visibleRows then return end

    -- If selected item is above current scroll position, scroll up
    if selectedCompletion <= completionsScrollPosition then
        completionsScrollPosition = selectedCompletion - 1
        -- If selected item is below visible area, scroll down
    elseif selectedCompletion > completionsScrollPosition + visibleRows then
        completionsScrollPosition = selectedCompletion - visibleRows
    end

    -- Ensure scroll position is within bounds
    completionsScrollPosition = math.max(0, math.min(completionsScrollPosition,
                                                     #completions - visibleRows))
end

-- Handle key presses
function PathInputDialog.keypressed(key, scancode, isrepeat)
    if not isOpen then return false end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local completionsY = 20 + height + 5
    local maxCompletionsHeight = screenHeight - completionsY - 20
    local maxRows = math.floor(maxCompletionsHeight / completionHeight)
    local visibleRows = math.min(maxRows, #completions)

    -- Track the last key for repeat handling
    lastKeyPressed = key
    repeatTimer = 0
    isRepeating = isrepeat

    if key == "escape" then
        -- Close dialog
        isOpen = false
        return true
    elseif key == "return" or key == "kpenter" then
        -- Submit the path
        if #completions > 0 and selectedCompletion <= #completions then
            -- If a completion is selected, use it
            local completion = completions[selectedCompletion]

            -- If it's a directory, update input text and refresh completions
            if completion.isDirectory then
                inputText = completion.fullPath
                cursorPosition = #inputText
                updateCompletions()
            else
                -- It's a file, validate and submit
                if validatePath(completion.fullPath) and callback then
                    local absolutePath = toAbsolutePath(completion.fullPath)
                    callback(absolutePath)
                    isOpen = false
                end
            end
        else
            -- No completion selected, validate and submit the raw input
            if validatePath(inputText) and callback then
                local absolutePath = toAbsolutePath(inputText)
                callback(absolutePath)
                isOpen = false
            end
        end
        return true
    elseif key == "tab" then
        -- Tab completion
        if #completions > 0 then
            local completion = completions[selectedCompletion]
            inputText = completion.fullPath
            cursorPosition = #inputText
            updateCompletions()
        end
        return true
    elseif key == "up" then
        -- Move completion selection up
        if #completions > 0 then
            selectedCompletion = selectedCompletion - 1
            if selectedCompletion < 1 then
                selectedCompletion = #completions
            end
            ensureSelectedVisible(visibleRows)
        end
        return true
    elseif key == "down" then
        -- Move completion selection down
        if #completions > 0 then
            selectedCompletion = selectedCompletion + 1
            if selectedCompletion > #completions then
                selectedCompletion = 1
            end
            ensureSelectedVisible(visibleRows)
        end
        return true
    elseif key == "pageup" then
        -- Move completion selection up by a page
        if #completions > 0 and visibleRows > 0 then
            selectedCompletion = math.max(1, selectedCompletion - visibleRows)
            ensureSelectedVisible(visibleRows)
        end
        return true
    elseif key == "pagedown" then
        -- Move completion selection down by a page
        if #completions > 0 and visibleRows > 0 then
            selectedCompletion = math.min(#completions,
                                          selectedCompletion + visibleRows)
            ensureSelectedVisible(visibleRows)
        end
        return true
    elseif key == "left" then
        -- Move cursor left
        cursorPosition = math.max(0, cursorPosition - 1)
        return true
    elseif key == "right" then
        -- Move cursor right
        cursorPosition = math.min(#inputText, cursorPosition + 1)
        return true
    elseif key == "home" then
        -- Move cursor to beginning
        cursorPosition = 0
        return true
    elseif key == "end" then
        -- Move cursor to end
        cursorPosition = #inputText
        return true
    elseif key == "backspace" then
        -- Delete character before cursor
        if cursorPosition > 0 then
            inputText = inputText:sub(1, cursorPosition - 1) ..
                            inputText:sub(cursorPosition + 1)
            cursorPosition = cursorPosition - 1
            updateCompletions()
        end
        return true
    elseif key == "delete" then
        -- Delete character after cursor
        if cursorPosition < #inputText then
            inputText = inputText:sub(1, cursorPosition) ..
                            inputText:sub(cursorPosition + 2)
            updateCompletions()
        end
        return true
    end

    return true
end

-- Handle text input
function PathInputDialog.textinput(text)
    if not isOpen then return false end

    -- Insert text at cursor position
    inputText = inputText:sub(1, cursorPosition) .. text ..
                    inputText:sub(cursorPosition + 1)
    cursorPosition = cursorPosition + #text

    -- Update completions
    updateCompletions()

    return true
end

-- Handle key releases
function PathInputDialog.keyreleased(key)
    if not isOpen then return false end

    -- If the released key is the one we're tracking, clear it
    if key == lastKeyPressed then
        lastKeyPressed = nil
        isRepeating = false
    end

    return true
end

-- Update function
function PathInputDialog.update(dt)
    if not isOpen then return end

    -- Update cursor blink
    blinkTimer = blinkTimer + dt
    if blinkTimer >= 0.5 then
        blinkTimer = blinkTimer - 0.5
        showCursor = not showCursor
    end

    -- Handle key repeat for navigation keys
    if lastKeyPressed then
        repeatTimer = repeatTimer + dt

        -- Check if we should trigger a repeat event
        local repeatTrigger = false
        if isRepeating then
            -- Already repeating, use the faster interval
            repeatTrigger = repeatTimer >= repeatInterval
        else
            -- Initial repeat, use the longer delay
            repeatTrigger = repeatTimer >= repeatDelay
        end

        if repeatTrigger then
            -- Reset timer and set repeating flag
            repeatTimer = 0
            isRepeating = true

            -- Process the repeated key - only one key at a time
            local repeatableKeys = {
                "left", "right", "up", "down", "backspace", "delete", "pageup",
                "pagedown"
            }

            -- Only process repeats for navigational keys
            for _, k in ipairs(repeatableKeys) do
                if lastKeyPressed == k then
                    -- Call keypressed with the repeat flag set to true
                    PathInputDialog.keypressed(lastKeyPressed, nil, true)
                    break
                end
            end
        end
    end

    -- If completions list is empty and we have input, update completions
    if #completions == 0 and #inputText > 0 then updateCompletions() end
end

-- Draw the dialog
function PathInputDialog.draw()
    if not isOpen then return end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local x = (screenWidth - width) / 2
    -- Position near the top of the screen with a small margin
    local y = 20

    -- Save entire graphics state
    love.graphics.push()

    -- Set font
    love.graphics.setFont(font)

    -- Draw background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)

    -- Draw border
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, width, height, 4, 4)

    -- Draw title
    love.graphics.setColor(fgColor)
    love.graphics.printf("Enter Script Path", x, y + 5, width, "center")

    -- Draw input box
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x + 10, y + 30, width - 20, 30, 2, 2)

    -- Draw input box border
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x + 10, y + 30, width - 20, 30, 2, 2)

    -- Draw input text
    love.graphics.setColor(fgColor)
    love.graphics.printf(inputText, x + 15, y + 36, width - 30, "left")

    -- Draw cursor
    if showCursor then
        local textWidth = font:getWidth(inputText:sub(1, cursorPosition))
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle("fill", x + 15 + textWidth, y + 36, 2,
                                font:getHeight())
    end

    -- Draw completions if any
    if #completions > 0 then
        local completionsY = y + height + 5
        local maxCompletionsHeight = screenHeight - completionsY - 20
        local maxRows = math.floor(maxCompletionsHeight / completionHeight)
        local visibleRows = math.min(maxRows, #completions)

        -- Set completion list dimensions
        local completionsWidth = width
        local completionsHeight = visibleRows * completionHeight

        -- Draw completion list background
        love.graphics.setColor(completionColor)
        love.graphics.rectangle("fill", x, completionsY, completionsWidth,
                                completionsHeight, 4, 4)

        -- Draw completion list border
        love.graphics.setColor(borderColor)
        love.graphics.rectangle("line", x, completionsY, completionsWidth,
                                completionsHeight, 4, 4)

        -- Draw visible completions
        for i = 1, visibleRows do
            local idx = i + completionsScrollPosition
            if idx <= #completions then
                local completion = completions[idx]
                local isSelected = idx == selectedCompletion

                -- Draw selection highlight
                if isSelected then
                    love.graphics.setColor(selectedCompletionColor)
                    love.graphics.rectangle("fill", x + 2, completionsY +
                                                (i - 1) * completionHeight,
                                            completionsWidth - 4,
                                            completionHeight)
                end

                -- Draw completion text with appropriate color
                if isSelected then
                    love.graphics.setColor(1, 1, 1, 1) -- White text for selected item
                else
                    love.graphics.setColor(fgColor)
                end

                -- Show icon based on if it's a file or directory
                local icon = completion.isDirectory and "📁 " or "📄 "
                love.graphics.print(icon .. completion.displayName, x + 10,
                                    completionsY + (i - 1) * completionHeight +
                                        5)
            end
        end

        -- Draw scroll indicators if needed
        if #completions > visibleRows then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8) -- Light gray, semi-transparent
            -- Up indicator (if not at top)
            if completionsScrollPosition > 0 then
                love.graphics.polygon("fill", x + completionsWidth / 2 - 10,
                                      completionsY + 5,
                                      x + completionsWidth / 2 + 10,
                                      completionsY + 5,
                                      x + completionsWidth / 2, completionsY - 5)
            end
            -- Down indicator (if not at bottom)
            if completionsScrollPosition + visibleRows < #completions then
                love.graphics.polygon("fill", x + completionsWidth / 2 - 10,
                                      completionsY + completionsHeight - 5,
                                      x + completionsWidth / 2 + 10,
                                      completionsY + completionsHeight - 5,
                                      x + completionsWidth / 2,
                                      completionsY + completionsHeight + 5)
            end
        end
    end

    -- Draw help text at the bottom
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8) -- Light gray, semi-transparent
    local helpFont = love.graphics.newFont(10)
    love.graphics.setFont(helpFont)
    love.graphics.printf(
        "Tab: Complete | ↑↓: Navigate | Enter: Select | Esc: Cancel", x,
        y + height - 18, width, "center")

    -- Restore entire graphics state
    love.graphics.pop()
end

-- Check if dialog is open
function PathInputDialog.isOpen() return isOpen end

-- Add mouse wheel support
function PathInputDialog.wheelmoved(x, y)
    if not isOpen or #completions == 0 then return false end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local completionsY = 20 + height + 5
    local maxCompletionsHeight = screenHeight - completionsY - 20
    local maxRows = math.floor(maxCompletionsHeight / completionHeight)
    local visibleRows = math.min(maxRows, #completions)

    -- Scroll the completions list (negative y means scroll up)
    completionsScrollPosition = completionsScrollPosition - y

    -- Ensure scroll position is within bounds
    completionsScrollPosition = math.max(0, math.min(completionsScrollPosition,
                                                     #completions - visibleRows))

    return true
end

-- Expose the module
return PathInputDialog

