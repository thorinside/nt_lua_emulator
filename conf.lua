-- conf.lua
-- LÖVE configuration script - runs before anything else
-- We need json for proper state parsing
local jsonFile = io.open("lib/dkjson.lua", "r")
local json
if jsonFile then
    -- Load the JSON module if available
    local jsonContent = jsonFile:read("*all")
    jsonFile:close()
    json = load(jsonContent)()
end

function love.conf(t)
    -- General settings
    t.title = "Disting NT LUA Emulator" -- The title of the window
    t.version = "11.3" -- The LÖVE version this game was made for
    t.console = false -- Attach a console

    -- Read state.json to determine the current UI mode
    local isMinimalMode = false
    local activeOverlay = "io" -- Default to IO overlay
    local scriptInputCount = 0
    local scriptOutputCount = 0
    local parameterCount = 0

    -- Try to read settings from state.json
    local stateFile = io.open("state.json", "r")
    if stateFile then
        local content = stateFile:read("*a")
        stateFile:close()

        -- Check for minimal mode
        if content:match('"minimalMode"%s*:%s*true') then
            isMinimalMode = true
        end

        -- Try to parse JSON properly if we have the json module
        if json and json.decode then
            local success, state = pcall(json.decode, content)
            if success and state then
                -- Get parameter count if available
                if state.scriptParameters then
                    parameterCount = #state.scriptParameters
                end

                -- Get input/output counts if available
                if state.inputs then
                    local maxInput = 0
                    for k, _ in pairs(state.inputs) do
                        local num = tonumber(k)
                        if num and num > maxInput then
                            maxInput = num
                        end
                    end
                    scriptInputCount = maxInput
                end

                if state.outputs then
                    local maxOutput = 0
                    for k, _ in pairs(state.outputs) do
                        local num = tonumber(k)
                        if num and num > maxOutput then
                            maxOutput = num
                        end
                    end
                    scriptOutputCount = maxOutput
                end

                -- Check for active overlay (controls vs io)
                if state.activeOverlay then
                    activeOverlay = state.activeOverlay
                end

                -- Get window position if available
                if state.window and state.window.x and state.window.y then
                    -- Set window position from saved state
                    t.window.x = state.window.x
                    t.window.y = state.window.y
                end
            end
        end
    end

    -- Display dimensions
    local displayWidth = 256
    local displayHeight = 64
    local displayScale = 3
    local scaledDisplayWidth = displayWidth * displayScale
    local scaledDisplayHeight = displayHeight * displayScale

    -- Calculate window size based on mode
    local windowWidth = scaledDisplayWidth
    local windowHeight

    if isMinimalMode then
        -- Minimal mode: just the display size
        windowHeight = scaledDisplayHeight
    else
        -- Non-minimal mode: calculate based on content
        if activeOverlay == "controls" then
            -- Controls overlay is smaller, roughly 300px
            windowHeight = scaledDisplayHeight + 300
        else
            -- IO overlay needs more space based on script IO count
            -- Estimate sizes:
            local scriptIOHeight = math.max(20, (scriptInputCount +
                                                scriptOutputCount) * 10)
            local physicalIOHeight = 200 -- Fixed height for physical IO
            local paramKnobRows = math.ceil(parameterCount / 9)
            local paramKnobHeight = 24 + (paramKnobRows * 24)

            -- Add some spacing between sections
            windowHeight = scaledDisplayHeight + scriptIOHeight +
                               physicalIOHeight + paramKnobHeight + 50
        end
    end

    -- Window settings
    t.window.title = "Disting NT LUA Emulator" -- Window title
    t.window.width = windowWidth
    t.window.height = windowHeight
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 8

    -- Start with window visible
    t.window.visible = true

    -- Modules settings
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end
