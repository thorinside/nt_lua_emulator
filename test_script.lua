-- Comprehensive test script for Disting NT API 1.10.0 features
local script = {}

-- State variables for demo
local displayModeIndex = 1
local displayModes = {"overview", "meters", "parameters", "ui", "algorithm", "menu"}
local modeChangeTime = 0
local frameCount = 0

script.inputs = {kCV, kCV, kCV, kCV}
script.outputs = {kCV, kCV, kCV, kCV}

function script.init()
    print("API 1.10.0 Test Script initialized!")
    print("Algorithm Index: " .. tostring(script.algorithmIndex))
    
    -- Test new query functions
    local algCount = getAlgorithmCount()
    print("Total algorithms available: " .. algCount)
    
    if algCount > 0 then
        print("First algorithm: " .. getAlgorithmName(0))
        local paramCount = getParameterCount(0)
        print("Parameters in algorithm 0: " .. paramCount)
        if paramCount > 0 then
            print("First parameter: " .. getParameterName(0, 0))
        end
    end
    
    -- Return the I/O configuration
    return {
        inputs = {kCV, kCV, kCV, kCV},
        outputs = {kCV, kCV, kCV, kCV}
    }
end

function script.process(inputs, outputs)
    frameCount = frameCount + 1
    
    -- Simple passthrough with some modulation
    for i = 1, 4 do
        outputs[i] = inputs[i] or 0
    end
    
    -- Cycle through display modes every 3 seconds
    if frameCount % 180 == 0 then  -- ~3 seconds at 60fps
        displayModeIndex = (displayModeIndex % #displayModes) + 1
        setDisplayMode(displayModes[displayModeIndex])
        modeChangeTime = frameCount
    end
end

function script.draw()
    -- Title with center alignment (new feature!)
    drawText(128, 10, "API 1.10.0 Feature Test", 15, "centre")
    
    -- Show current display mode with right alignment
    local modeText = "Mode: " .. displayModes[displayModeIndex]
    drawText(254, 20, modeText, 15, "right")
    
    -- Left aligned info
    drawText(2, 20, "Alg Index: " .. tostring(script.algorithmIndex or "nil"), 15, "left")
    
    -- Demo text alignment options
    drawTinyText(2, 30, "LEFT", 15, "left")
    drawTinyText(128, 30, "CENTER", 15, "centre")
    drawTinyText(254, 30, "RIGHT", 15, "right")
    
    -- Show algorithm info if available
    local algCount = getAlgorithmCount()
    if algCount > 0 and script.algorithmIndex then
        local algName = getAlgorithmName(script.algorithmIndex)
        local paramCount = getParameterCount(script.algorithmIndex)
        
        drawText(128, 42, "Current: " .. (algName or "Unknown"), 15, "centre")
        drawTinyText(128, 50, "Params: " .. (paramCount or 0), 15, "centre")
        
        -- Show first parameter name if available
        if paramCount and paramCount > 0 then
            local paramName = getParameterName(script.algorithmIndex, 1)
            drawTinyText(128, 58, "P1: " .. (paramName or "?"), 15, "centre")
        end
    else
        drawText(128, 46, "No algorithm loaded", 15, "centre")
    end
end

-- Control callbacks to test interactivity
function script.button1Push(self)
    print("===== BUTTON 1 PRESSED =====")
    print("Testing getAlgorithmName function")
    local algCount = getAlgorithmCount()
    print("Total algorithms: " .. algCount)
    for i = 0, math.min(4, algCount - 1) do  -- Use 0-based indexing
        local name = getAlgorithmName(i)
        print(string.format("  Algorithm %d: %s", i, name or "nil"))
    end
    print("===========================")
end

function script.button2Push(self)
    print("===== BUTTON 2 PRESSED =====")
    print("Testing getParameterName function")
    local algIndex = self.algorithmIndex or 0
    print("Current algorithm index: " .. algIndex)
    local paramCount = getParameterCount(algIndex)
    if paramCount and paramCount > 0 then
        print("Parameters for algorithm " .. algIndex .. " (count: " .. paramCount .. "):")
        for i = 0, math.min(4, paramCount - 1) do  -- Use 0-based indexing
            local name = getParameterName(algIndex, i)
            print(string.format("  Parameter %d: %s", i, name or "nil"))
        end
    else
        print("No parameters found for algorithm " .. algIndex)
    end
    print("===========================")
end

-- Also add button 3 and 4 for testing
function script.button3Push(self)
    print("===== BUTTON 3 PRESSED =====")
    print("Cycling display mode manually")
    displayModeIndex = (displayModeIndex % #displayModes) + 1
    setDisplayMode(displayModes[displayModeIndex])
    modeChangeTime = frameCount
    print("Display mode changed to: " .. displayModes[displayModeIndex])
    print("===========================")
end

function script.button4Push(self)
    print("===== BUTTON 4 PRESSED =====")
    print("Testing algorithmIndex property")
    print("self.algorithmIndex = " .. tostring(self.algorithmIndex))
    print("===========================")
end

function script.encoder1Turn(self, delta)
    -- Manually cycle display modes with encoder
    if type(delta) == "table" then
        delta = delta[1] or 0  -- Extract first value if it's a table
    end
    
    if delta > 0 then
        displayModeIndex = (displayModeIndex % #displayModes) + 1
    else
        displayModeIndex = displayModeIndex - 1
        if displayModeIndex < 1 then displayModeIndex = #displayModes end
    end
    setDisplayMode(displayModes[displayModeIndex])
    modeChangeTime = frameCount
    print("Display mode changed to: " .. displayModes[displayModeIndex])
end

return script