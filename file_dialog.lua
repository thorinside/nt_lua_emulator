-- file_dialog.lua
-- Implements a simple file dialog for the emulator
local FileDialog = {}

-- State
local isOpen = false
local currentDir = nil
local files = {}
local directories = {}
local selectedIndex = 1
local scroll = 0
local scrollSpeed = 10
local callback = nil
local filterLua = true
local dirStack = {}
local lastClickTime = 0
local lastClickIndex = 0

-- Colors and dimensions
local bgColor = {0.1, 0.1, 0.1, 0.95}
local fgColor = {1, 1, 1, 1}
local selectionColor = {0.3, 0.6, 0.9, 0.6}
local borderColor = {0.5, 0.5, 0.5, 1}
local width = 600
local height = 400
local itemHeight = 24
local font = nil
local titleFont = nil

-- Initialize the module
function FileDialog.init()
    -- Set default directory to the current one
    currentDir = love.filesystem.getWorkingDirectory()

    -- Initialize fonts
    font = love.graphics.newFont(12)
    titleFont = love.graphics.newFont(16)
end

-- List files and directories in the current directory
local function listDirectory()
    files = {}
    directories = {}

    -- Use io.popen to list directories and files
    local cmd = 'ls -la "' .. currentDir .. '" 2>/dev/null'
    local handle = io.popen(cmd)

    if not handle then
        print("Failed to list directory: " .. currentDir)
        return
    end

    for line in handle:lines() do
        -- Skip the first two lines (. and ..)
        if not line:match("^total") then
            local isDir = line:match("^d")
            local name = line:match(
                             "[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +(.+)$")

            if name and name ~= "." and name ~= ".." then
                if isDir then
                    table.insert(directories, name)
                else
                    if not filterLua or name:match("%.lua$") then
                        table.insert(files, name)
                    end
                end
            end
        end
    end

    handle:close()

    -- Sort directories and files alphabetically
    table.sort(directories)
    table.sort(files)

    -- Always add ".." to go up one directory, except at root
    if currentDir ~= "/" then table.insert(directories, 1, "..") end

    -- Reset selection
    selectedIndex = 1
    scroll = 0
end

-- Open the file dialog
function FileDialog.open(onFileSelected)
    if isOpen then return end

    -- Store callback
    callback = onFileSelected

    -- Get script directory from config
    local config = require("config")
    local cfg = config.load()
    local scriptDir = love.filesystem.getWorkingDirectory()

    -- Extract directory from existing script path if available
    if cfg.script and cfg.script.path then
        -- Get directory portion of the path
        local path = cfg.script.path
        if path:sub(1, 1) == "/" then
            -- Absolute path, extract directory
            scriptDir = path:match("(.+)/[^/]*%.lua$") or scriptDir
        end
    end

    -- Set the current directory
    currentDir = scriptDir
    print("Opening file dialog in: " .. currentDir)

    -- List files in the directory
    listDirectory()

    isOpen = true
end

-- Handle key presses
function FileDialog.keypressed(key)
    if not isOpen then return false end

    if key == "escape" then
        -- Close dialog
        isOpen = false
        return true
    elseif key == "up" then
        -- Move selection up
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = #directories + #files end
        return true
    elseif key == "down" then
        -- Move selection down
        selectedIndex = selectedIndex + 1
        if selectedIndex > #directories + #files then selectedIndex = 1 end
        return true
    elseif key == "return" or key == "kpenter" then
        -- Select current item
        if selectedIndex <= #directories then
            -- It's a directory, navigate into it
            local dirName = directories[selectedIndex]

            if dirName == ".." then
                -- Go up one directory
                local parentDir = currentDir:match("(.+)/[^/]+$")
                if parentDir and parentDir ~= "" then
                    currentDir = parentDir
                else
                    currentDir = "/"
                end
            else
                -- Navigate to subdirectory
                if currentDir:sub(-1) == "/" then
                    currentDir = currentDir .. dirName
                else
                    currentDir = currentDir .. "/" .. dirName
                end
            end

            listDirectory()
        else
            -- It's a file, select it
            local fileName = files[selectedIndex - #directories]
            if callback then
                local fullPath
                if currentDir:sub(-1) == "/" then
                    fullPath = currentDir .. fileName
                else
                    fullPath = currentDir .. "/" .. fileName
                end
                callback(fullPath)
            end
            isOpen = false
        end
        return true
    elseif key == "backspace" then
        -- Go back to parent directory
        local parentDir = currentDir:match("(.+)/[^/]+$")
        if parentDir and parentDir ~= "" then
            currentDir = parentDir
        else
            currentDir = "/"
        end
        listDirectory()
        return true
    elseif key == "f" then
        -- Toggle filter
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            filterLua = not filterLua
            listDirectory()
            return true
        end
    end

    return true
end

-- Add mouse wheel support
function FileDialog.wheelmoved(x, y)
    if not isOpen then return false end

    -- Scroll the list
    scroll = scroll - y * scrollSpeed

    -- Clamp scroll values
    local maxScroll = math.max(0, (#directories + #files) * itemHeight -
                                   (height - 95))
    scroll = math.max(0, math.min(scroll, maxScroll))

    return true
end

-- Add mouse click support
function FileDialog.mousepressed(mx, my, button)
    if not isOpen then return false end

    -- Get dialog position
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2

    -- Check if clicked inside the dialog
    if mx >= x and mx <= x + width and my >= y and my <= y + height then
        -- Check if clicked in the file list area
        if my >= y + 65 and my <= y + height - 30 then
            -- Calculate which item was clicked
            local relativeY = my - (y + 65) + scroll
            local clickedIndex = math.floor(relativeY / itemHeight) + 1

            -- Set selection if valid
            if clickedIndex >= 1 and clickedIndex <= #directories + #files then
                selectedIndex = clickedIndex

                -- Double-click to select
                if button == 1 and love.timer.getTime() - (lastClickTime or 0) <
                    0.4 and lastClickIndex == clickedIndex then
                    -- Handle selection (same as pressing Enter)
                    if selectedIndex <= #directories then
                        -- It's a directory, navigate into it
                        local dirName = directories[selectedIndex]

                        if dirName == ".." then
                            -- Go up one directory
                            local parentDir = currentDir:match("(.+)/[^/]+$")
                            if parentDir and parentDir ~= "" then
                                currentDir = parentDir
                            else
                                currentDir = "/"
                            end
                        else
                            -- Navigate to subdirectory
                            if currentDir:sub(-1) == "/" then
                                currentDir = currentDir .. dirName
                            else
                                currentDir = currentDir .. "/" .. dirName
                            end
                        end

                        listDirectory()
                    else
                        -- It's a file, select it
                        local fileName = files[selectedIndex - #directories]
                        if callback then
                            local fullPath
                            if currentDir:sub(-1) == "/" then
                                fullPath = currentDir .. fileName
                            else
                                fullPath = currentDir .. "/" .. fileName
                            end
                            callback(fullPath)
                        end
                        isOpen = false
                    end
                end

                lastClickTime = love.timer.getTime()
                lastClickIndex = clickedIndex
            end
        end
        return true
    else
        -- Clicked outside the dialog, close it
        if button == 1 then isOpen = false end
        return true
    end

    return false
end

-- Update function
function FileDialog.update(dt)
    -- Nothing to update
end

-- Draw the dialog
function FileDialog.draw()
    if not isOpen then return end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2

    -- Save current graphics state
    local r, g, b, a = love.graphics.getColor()
    local prevFont = love.graphics.getFont()

    -- Draw background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)

    -- Draw border
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, width, height, 4, 4)

    -- Draw title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(fgColor)
    love.graphics.printf("Select Script File", x, y + 10, width, "center")

    -- Draw current directory
    love.graphics.setFont(font)
    love.graphics.printf(currentDir, x + 10, y + 40, width - 20, "left")

    -- Draw separator
    love.graphics.setColor(borderColor)
    love.graphics.line(x + 5, y + 60, x + width - 5, y + 60)

    -- Draw files and directories
    love.graphics.setFont(font)
    love.graphics.setScissor(x + 5, y + 65, width - 10, height - 95)

    for i, dir in ipairs(directories) do
        local itemY = y + 65 + (i - 1) * itemHeight - scroll

        -- Only draw if visible
        if itemY + itemHeight > y + 65 and itemY < y + height - 30 then
            -- Draw selection background
            if i == selectedIndex then
                love.graphics.setColor(selectionColor)
                love.graphics.rectangle("fill", x + 5, itemY, width - 10,
                                        itemHeight)
            end

            -- Draw directory name
            love.graphics.setColor(fgColor)
            love.graphics.print("📁 " .. dir, x + 10, itemY + 4)
        end
    end

    for i, file in ipairs(files) do
        local itemY = y + 65 + (#directories + i - 1) * itemHeight - scroll

        -- Only draw if visible
        if itemY + itemHeight > y + 65 and itemY < y + height - 30 then
            -- Draw selection background
            if #directories + i == selectedIndex then
                love.graphics.setColor(selectionColor)
                love.graphics.rectangle("fill", x + 5, itemY, width - 10,
                                        itemHeight)
            end

            -- Draw file name
            love.graphics.setColor(fgColor)
            love.graphics.print("📄 " .. file, x + 10, itemY + 4)
        end
    end

    love.graphics.setScissor()

    -- Draw instructions
    love.graphics.setColor(borderColor)
    love.graphics.line(x + 5, y + height - 30, x + width - 5, y + height - 30)

    love.graphics.setColor(fgColor)
    love.graphics.printf(
        "↑↓ Navigate    Enter: Select    Backspace: Back    Ctrl+F: Toggle Filter (" ..
            (filterLua and "Lua Only" or "All Files") .. ")", x + 10,
        y + height - 25, width - 20, "center")

    -- Restore graphics state
    love.graphics.setColor(r, g, b, a)
    love.graphics.setFont(prevFont)
end

-- Check if dialog is open
function FileDialog.isOpen() return isOpen end

return FileDialog
