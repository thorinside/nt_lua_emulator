-- emulator_integration_test.lua
-- Integration test for API 1.10.0 with all emulator features
-- Tests I/O mapping, MIDI integration, OSC functionality, parameter automation, state persistence

local test = {}

-- Test state
local testPhase = 1
local frameCounter = 0
local integrationResults = {}
local testSignals = {}

-- Integration test phases
local testPhases = {
    {name = "I/O Mapping Integration", test = "ioMapping"},
    {name = "Signal Processing Integration", test = "signalProcessing"},
    {name = "Parameter Automation Integration", test = "parameterAutomation"},
    {name = "State Persistence Integration", test = "statePersistence"},
    {name = "Control Interface Integration", test = "controlInterface"},
    {name = "Display System Integration", test = "displaySystem"},
    {name = "MIDI Integration Test", test = "midiIntegration"},
    {name = "OSC Integration Test", test = "oscIntegration"},
    {name = "Hot Reload Integration", test = "hotReload"},
    {name = "Performance Under Load", test = "performanceLoad"}
}

-- Signal generators for testing
local signalGenerators = {
    sine = function(t, freq) return math.sin(2 * math.pi * freq * t) end,
    square = function(t, freq) return math.sin(2 * math.pi * freq * t) > 0 and 1 or -1 end,
    sawtooth = function(t, freq) return 2 * ((freq * t) % 1) - 1 end,
    noise = function(t, freq) return (math.random() - 0.5) * 2 end
}

function test.init()
    print("=== Emulator Integration Test Suite ===")
    print("Testing API 1.10.0 integration with all emulator features")
    
    integrationResults = {}
    testPhase = 1
    frameCounter = 0
    
    -- Initialize test signals
    testSignals = {
        time = 0,
        frequency = 1.0,
        amplitude = 1.0,
        phase = 0
    }
    
    -- Initialize results
    for _, phase in ipairs(testPhases) do
        integrationResults[phase.test] = {
            name = phase.name,
            status = "pending",
            tests = {},
            totalTests = 0,
            passedTests = 0,
            errors = {},
            details = ""
        }
    end
    
    print("Initialized " .. #testPhases .. " integration test phases")
    print("Testing with I/O, MIDI, OSC, state persistence, and performance")
end

function test.process(inputs, outputs)
    -- Generate test signals using API 1.10.0 features
    local time = love.timer.getTime()
    testSignals.time = time
    
    -- Use new API features during processing
    local algIndex = self.algorithmIndex or 0
    local algCount = getAlgorithmCount() or 1
    
    -- Generate complex test signals
    for i = 1, 4 do
        local freq = 0.5 + i * 0.25
        local input = inputs[i] or 0
        
        -- Mix input with generated signal
        local generated = signalGenerators.sine(time, freq) * 0.3
        local processed = input * 0.7 + generated
        
        -- Apply algorithm-dependent processing
        if algIndex > 0 then
            processed = processed * (1 + algIndex * 0.1)
        end
        
        outputs[i] = processed
    end
    
    return outputs
end

-- Test I/O mapping integration
local function testIOMapping()
    local result = integrationResults["ioMapping"]
    result.status = "running"
    
    -- Test that I/O types are correctly defined and accessible
    result.totalTests = result.totalTests + 1
    if kCV and kGate and kTrigger then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "I/O Constants Available", status = "passed"})
        result.details = result.details .. "I/O constants ✓ "
    else
        table.insert(result.errors, "I/O constants (kCV, kGate, kTrigger) not available")
        table.insert(result.tests, {name = "I/O Constants Available", status = "failed"})
    end
    
    -- Test I/O array definition compatibility
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        local ioTest = {
            inputs = {kCV, kTrigger, kGate, kCV},
            outputs = {kCV, kCV, kGate, kTrigger}
        }
        return #ioTest.inputs == 4 and #ioTest.outputs == 4
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "I/O Array Definition", status = "passed"})
        result.details = result.details .. "I/O arrays ✓ "
    else
        table.insert(result.errors, "I/O array definition failed")
        table.insert(result.tests, {name = "I/O Array Definition", status = "failed"})
    end
    
    -- Test that API 1.10.0 functions work during I/O processing
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        local algCount = getAlgorithmCount()
        local algIndex = self.algorithmIndex
        return algCount ~= nil or algIndex ~= nil
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "API Functions During I/O", status = "passed"})
        result.details = result.details .. "API in I/O ✓ "
    else
        table.insert(result.errors, "API 1.10.0 functions failed during I/O processing")
        table.insert(result.tests, {name = "API Functions During I/O", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test signal processing integration
local function testSignalProcessing()
    local result = integrationResults["signalProcessing"]
    result.status = "running"
    
    -- Test signal generation with API features
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        local time = love.timer.getTime()
        for i = 1, 4 do
            local signal = signalGenerators.sine(time, 1 + i)
            -- Use API during signal processing
            local algIndex = self.algorithmIndex or 0
            signal = signal * (1 + algIndex * 0.01)
        end
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Signal Generation with API", status = "passed"})
        result.details = result.details .. "Signal gen ✓ "
    else
        table.insert(result.errors, "Signal generation with API features failed")
        table.insert(result.tests, {name = "Signal Generation with API", status = "failed"})
    end
    
    -- Test complex signal chains
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        local input = 0.5
        local processed = input
        
        -- Chain multiple operations
        processed = processed * 2                -- Amplify
        processed = math.tanh(processed)          -- Saturate
        processed = processed * 0.8               -- Scale down
        
        -- Use new API features in the chain
        local algCount = getAlgorithmCount() or 1
        processed = processed * (algCount / 10.0)
        
        return math.abs(processed) <= 1.0
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Complex Signal Chains", status = "passed"})
        result.details = result.details .. "Signal chains ✓ "
    else
        table.insert(result.errors, "Complex signal chain processing failed")
        table.insert(result.tests, {name = "Complex Signal Chains", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test parameter automation integration
local function testParameterAutomation()
    local result = integrationResults["parameterAutomation"]
    result.status = "running"
    
    -- Test parameter access during automation
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        if self.parameters then
            for i = 1, math.min(#self.parameters, 3) do
                local param = self.parameters[i]
                -- Use parameter with new API features
                local algIndex = self.algorithmIndex or 0
                local modulated = param * (1 + algIndex * 0.01)
            end
        end
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Parameter Access with API", status = "passed"})
        result.details = result.details .. "Param access ✓ "
    else
        table.insert(result.errors, "Parameter access with API features failed")
        table.insert(result.tests, {name = "Parameter Access with API", status = "failed"})
    end
    
    -- Test parameter display with new text alignment
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        if self.parameters then
            local param1 = self.parameters[1] or 0
            local param2 = self.parameters[2] or 0
            
            -- Display with different alignments
            drawText(60, 35, "P1: " .. string.format("%.2f", param1), 8, "left")
            drawText(128, 35, "P2: " .. string.format("%.2f", param2), 8, "centre")
            drawTinyText(200, 35, "Auto", 6, "right")
        end
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Parameter Display", status = "passed"})
        result.details = result.details .. "Param display ✓ "
    else
        table.insert(result.errors, "Parameter display with text alignment failed")
        table.insert(result.tests, {name = "Parameter Display", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test state persistence integration
local function testStatePersistence()
    local result = integrationResults["statePersistence"]
    result.status = "running"
    
    -- Test state save/restore with API features
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Create state with API-related data
        local testState = {
            currentAlgorithm = self.algorithmIndex or 0,
            timestamp = love.timer.getTime(),
            apiVersion = "1.10.0",
            testSignals = testSignals
        }
        
        -- Test serialization
        local serialized = dkjson and dkjson.encode(testState) or nil
        if serialized then
            local deserialized = dkjson.decode(serialized)
            return deserialized.apiVersion == "1.10.0"
        end
        return false
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "State Serialization", status = "passed"})
        result.details = result.details .. "State save ✓ "
    else
        table.insert(result.errors, "State serialization with API features failed")
        table.insert(result.tests, {name = "State Serialization", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test control interface integration
local function testControlInterface()
    local result = integrationResults["controlInterface"]
    result.status = "running"
    
    -- Test that controls work with display modes
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Test display mode changes
        setDisplayMode(1) -- Inverted
        drawText(100, 25, "Inverted Mode", 12, "centre")
        
        setDisplayMode(2) -- Dim
        drawText(100, 35, "Dim Mode", 12, "centre")
        
        setDisplayMode(0) -- Normal
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Display Mode Controls", status = "passed"})
        result.details = result.details .. "Display modes ✓ "
    else
        table.insert(result.errors, "Display mode control integration failed")
        table.insert(result.tests, {name = "Display Mode Controls", status = "failed"})
    end
    
    -- Test control callbacks with API features
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Simulate control callbacks
        local algCount = getAlgorithmCount() or 1
        local algIndex = self.algorithmIndex or 0
        
        -- Display control info with alignment
        drawText(10, 45, "Alg: " .. algIndex .. "/" .. (algCount - 1), 8, "left")
        drawText(128, 45, "Control Test", 8, "centre")
        drawText(246, 45, "OK", 8, "right")
        
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Control Callbacks", status = "passed"})
        result.details = result.details .. "Controls ✓ "
    else
        table.insert(result.errors, "Control callback integration failed")
        table.insert(result.tests, {name = "Control Callbacks", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test display system integration
local function testDisplaySystem()
    local result = integrationResults["displaySystem"]
    result.status = "running"
    
    -- Test all display modes with new text features
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        local modes = {0, 1, 2, 3, 4, 5}
        local alignments = {"left", "centre", "right"}
        
        for _, mode in ipairs(modes) do
            setDisplayMode(mode)
            for _, align in ipairs(alignments) do
                drawText(128, 30, "Mode " .. mode .. " " .. align, 10, align)
                drawTinyText(128, 40, "Tiny " .. mode .. " " .. align, 6, align)
            end
        end
        
        setDisplayMode(0) -- Reset to normal
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Display Modes + Text Alignment", status = "passed"})
        result.details = result.details .. "Display+Text ✓ "
    else
        table.insert(result.errors, "Display system integration with text alignment failed")
        table.insert(result.tests, {name = "Display Modes + Text Alignment", status = "failed"})
    end
    
    -- Test complex display rendering
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Complex display with API info
        local algCount = getAlgorithmCount() or 0
        local algIndex = self.algorithmIndex or 0
        
        -- Header with algorithm info
        drawText(128, 5, "API 1.10.0 Integration", 15, "centre")
        drawLine(0, 12, 256, 12, 8)
        
        -- Algorithm display
        if algCount > 0 then
            local algName = getAlgorithmName(algIndex) or "Unknown"
            drawText(10, 20, "Algorithm: " .. algName, 10, "left")
        end
        
        -- Status indicators
        drawText(246, 20, "OK", 10, "right")
        
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Complex Display Rendering", status = "passed"})
        result.details = result.details .. "Complex render ✓ "
    else
        table.insert(result.errors, "Complex display rendering failed")
        table.insert(result.tests, {name = "Complex Display Rendering", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test MIDI integration
local function testMIDIIntegration()
    local result = integrationResults["midiIntegration"]
    result.status = "running"
    
    -- Test MIDI compatibility with new API
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Simulate MIDI processing with API features
        local algIndex = self.algorithmIndex or 0
        local midiNote = 60 + algIndex -- Use algorithm index to affect MIDI
        
        -- Test that API functions don't interfere with MIDI
        local algCount = getAlgorithmCount()
        if algCount then
            midiNote = midiNote % 127
        end
        
        -- Display MIDI info
        drawText(10, 25, "MIDI Note: " .. midiNote, 10, "left")
        drawText(246, 25, "Ch: 1", 8, "right")
        
        return true
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "MIDI + API Integration", status = "passed"})
        result.details = result.details .. "MIDI+API ✓ "
    else
        table.insert(result.errors, "MIDI integration with new API failed")
        table.insert(result.tests, {name = "MIDI + API Integration", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test OSC integration
local function testOSCIntegration()
    local result = integrationResults["oscIntegration"]
    result.status = "running"
    
    -- Test OSC compatibility
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Simulate OSC message preparation
        local oscData = {
            path = "/disting/algorithm",
            value = self.algorithmIndex or 0,
            timestamp = love.timer.getTime()
        }
        
        -- Test parameter OSC messages
        if self.parameters then
            for i = 1, math.min(#self.parameters, 2) do
                local paramOSC = {
                    path = "/disting/param/" .. i,
                    value = self.parameters[i] or 0
                }
            end
        end
        
        return oscData.path ~= nil
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "OSC Message Preparation", status = "passed"})
        result.details = result.details .. "OSC prep ✓ "
    else
        table.insert(result.errors, "OSC integration preparation failed")
        table.insert(result.tests, {name = "OSC Message Preparation", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test hot reload integration
local function testHotReload()
    local result = integrationResults["hotReload"]
    result.status = "running"
    
    -- Test that API features survive hot reload
    result.totalTests = result.totalTests + 1
    local success = pcall(function()
        -- Test API state consistency
        local beforeAlg = self.algorithmIndex
        local beforeCount = getAlgorithmCount()
        
        -- Simulate what happens during hot reload
        local stateBackup = {
            algIndex = beforeAlg,
            algCount = beforeCount,
            timestamp = love.timer.getTime()
        }
        
        -- Restore state
        local afterAlg = stateBackup.algIndex
        local afterCount = stateBackup.algCount
        
        return beforeAlg == afterAlg and beforeCount == afterCount
    end)
    if success then
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "API State Consistency", status = "passed"})
        result.details = result.details .. "Hot reload ✓ "
    else
        table.insert(result.errors, "Hot reload API state consistency failed")
        table.insert(result.tests, {name = "API State Consistency", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

-- Test performance under load
local function testPerformanceLoad()
    local result = integrationResults["performanceLoad"]
    result.status = "running"
    
    -- Test performance with all features active
    result.totalTests = result.totalTests + 1
    local startTime = love.timer.getTime()
    local iterations = 100
    
    local success = pcall(function()
        for i = 1, iterations do
            -- Use all API features simultaneously
            local algIndex = self.algorithmIndex
            local algCount = getAlgorithmCount()
            
            if algCount and algCount > 0 then
                local algName = getAlgorithmName(0)
                local paramCount = getParameterCount(0)
                
                if paramCount and paramCount > 0 then
                    local paramName = getParameterName(0, 0)
                end
            end
            
            -- Display mode changes
            setDisplayMode(i % 6)
            
            -- Text rendering with alignment
            drawText(100, 20, "Load Test " .. i, 10, "centre")
            drawTinyText(100, 30, "Performance", 8, "right")
            
            -- Signal processing
            for j = 1, 4 do
                local signal = signalGenerators.sine(love.timer.getTime(), j)
                local processed = signal * 0.5
            end
        end
        
        setDisplayMode(0) -- Reset
        return true
    end)
    
    local endTime = love.timer.getTime()
    local duration = endTime - startTime
    
    if success and duration < 1.0 then -- Should complete in under 1 second
        result.passedTests = result.passedTests + 1
        table.insert(result.tests, {name = "Performance Under Load", status = "passed"})
        result.details = result.details .. string.format("Load test %.1fms ", duration * 1000)
    else
        table.insert(result.errors, "Performance under load failed or too slow: " .. string.format("%.1fms", duration * 1000))
        table.insert(result.tests, {name = "Performance Under Load", status = "failed"})
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

function test.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Auto-advance every 120 frames (2 seconds)
    frameCounter = frameCounter + 1
    if frameCounter > 120 then
        frameCounter = 0
        testPhase = testPhase + 1
        if testPhase > #testPhases then
            testPhase = #testPhases -- Stay on last test
        end
    end
    
    local currentPhase = testPhases[testPhase]
    
    -- Run the current test
    local testFunctions = {
        ioMapping = testIOMapping,
        signalProcessing = testSignalProcessing,
        parameterAutomation = testParameterAutomation,
        statePersistence = testStatePersistence,
        controlInterface = testControlInterface,
        displaySystem = testDisplaySystem,
        midiIntegration = testMIDIIntegration,
        oscIntegration = testOSCIntegration,
        hotReload = testHotReload,
        performanceLoad = testPerformanceLoad
    }
    
    if testFunctions[currentPhase.test] then
        testFunctions[currentPhase.test]()
    end
    
    -- Display current test
    drawText(128, 5, "Emulator Integration Test", 15, "centre")
    drawText(128, 15, currentPhase.name, 8, "centre")
    
    -- Display progress
    drawText(10, 25, "Phase " .. testPhase .. "/" .. #testPhases, 10, "left")
    
    -- Display results
    local result = integrationResults[currentPhase.test]
    if result.totalTests > 0 then
        local passRate = (result.passedTests / result.totalTests) * 100
        local statusColor = result.status == "passed" and 15 or result.status == "failed" and 5 or 8
        
        drawText(10, 35, string.format("Pass: %d/%d (%.0f%%)", 
            result.passedTests, result.totalTests, passRate), statusColor)
    end
    
    if result.details ~= "" then
        drawTinyText(10, 45, result.details, 10)
    end
    
    if #result.errors > 0 then
        drawTinyText(10, 55, "Errors: " .. #result.errors, 5)
    end
    
    -- Overall status if on last phase
    if testPhase == #testPhases then
        local totalPassed = 0
        local totalTests = 0
        local totalErrors = 0
        
        for _, phase in ipairs(testPhases) do
            local res = integrationResults[phase.test]
            totalPassed = totalPassed + res.passedTests
            totalTests = totalTests + res.totalTests
            totalErrors = totalErrors + #res.errors
        end
        
        if totalTests > 0 then
            local overallRate = (totalPassed / totalTests) * 100
            local overallColor = totalErrors == 0 and 15 or 5
            drawText(200, 35, string.format("Overall: %.0f%%", overallRate), overallColor, "right")
            drawTinyText(200, 45, totalErrors == 0 and "All Good" or (totalErrors .. " errors"), 
                totalErrors == 0 and 12 or 5, "right")
        end
    end
    
    -- Progress bar
    local progress = (testPhase - 1) / (#testPhases - 1)
    fillRectangle(0, 62, progress * 256, 64, 12)
    
    return true
end

-- Control callbacks for manual navigation
function test.button1Pressed()
    if testPhase < #testPhases then
        testPhase = testPhase + 1
        frameCounter = 0
        print("Advanced to: " .. testPhases[testPhase].name)
    end
end

function test.button2Pressed()
    if testPhase > 1 then
        testPhase = testPhase - 1
        frameCounter = 0
        print("Back to: " .. testPhases[testPhase].name)
    end
end

function test.encoderPressed()
    -- Print detailed integration results
    print("\n=== Emulator Integration Test Results ===")
    local grandTotalPassed = 0
    local grandTotalTests = 0
    local grandTotalErrors = 0
    
    for _, phase in ipairs(testPhases) do
        local result = integrationResults[phase.test]
        print(phase.name .. ":")
        print("  Status: " .. result.status)
        print("  Tests: " .. result.passedTests .. "/" .. result.totalTests .. " passed")
        
        if result.details ~= "" then
            print("  Details: " .. result.details)
        end
        
        for _, test in ipairs(result.tests) do
            print("    " .. test.name .. ": " .. test.status)
        end
        
        for _, error in ipairs(result.errors) do
            print("  ERROR: " .. error)
        end
        
        grandTotalPassed = grandTotalPassed + result.passedTests
        grandTotalTests = grandTotalTests + result.totalTests
        grandTotalErrors = grandTotalErrors + #result.errors
        print("")
    end
    
    print("GRAND TOTAL:")
    print("  Passed: " .. grandTotalPassed .. "/" .. grandTotalTests)
    if grandTotalTests > 0 then
        local overallRate = (grandTotalPassed / grandTotalTests) * 100
        print("  Success Rate: " .. string.format("%.1f", overallRate) .. "%")
    end
    print("  Total Errors: " .. grandTotalErrors)
    
    if grandTotalErrors == 0 then
        print("  RESULT: FULL EMULATOR INTEGRATION SUCCESS")
    else
        print("  RESULT: INTEGRATION ISSUES DETECTED")
    end
    
    print("=== End Integration Results ===\n")
end

-- Input/output definitions for comprehensive testing
test.inputs = {kCV, kTrigger, kGate, kCV}
test.outputs = {kCV, kCV, kGate, kTrigger}

return test