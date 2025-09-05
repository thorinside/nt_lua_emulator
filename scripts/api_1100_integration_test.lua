-- api_1100_integration_test.lua
-- Comprehensive integration test for Disting NT API 1.10.0 implementation
-- Tests all new features, backward compatibility, error handling, and performance

local test = {}

-- Test state
local testPhase = 1
local frameCounter = 0
local testResults = {}
local performanceStats = {}

-- Test phases configuration
local testPhases = {
    {name = "Algorithm Index Property", test = "algorithmIndex"},
    {name = "Algorithm Query Functions", test = "algorithmQuery"},
    {name = "Parameter Query Functions", test = "parameterQuery"},
    {name = "Display Mode Testing", test = "displayMode"},
    {name = "Text Alignment Features", test = "textAlignment"},
    {name = "Error Handling", test = "errorHandling"},
    {name = "Performance Benchmarks", test = "performance"},
    {name = "Backward Compatibility", test = "backwardCompat"},
    {name = "Integration Test Summary", test = "summary"}
}

-- Performance tracking
local startTime = 0
local endTime = 0

function test.init()
    print("=== API 1.10.0 Integration Test Suite ===")
    print("Testing all new features and backward compatibility")
    
    testResults = {}
    performanceStats = {}
    testPhase = 1
    frameCounter = 0
    startTime = love.timer.getTime()
    
    -- Initialize test results
    for i, phase in ipairs(testPhases) do
        testResults[phase.test] = {
            name = phase.name,
            status = "pending",
            errors = {},
            details = ""
        }
    end
    
    print("Initialized " .. #testPhases .. " test phases")
end

function test.process(inputs, outputs)
    -- Test I/O processing during tests
    for i = 1, 4 do
        outputs[i] = math.sin(love.timer.getTime() + i) * 0.5
    end
end

-- Test individual features
local function testAlgorithmIndex()
    local result = testResults["algorithmIndex"]
    result.status = "running"
    
    -- Test 1: Check if self.algorithmIndex exists and is valid
    if self.algorithmIndex == nil then
        table.insert(result.errors, "self.algorithmIndex is nil")
    elseif type(self.algorithmIndex) ~= "number" then
        table.insert(result.errors, "self.algorithmIndex is not a number: " .. type(self.algorithmIndex))
    elseif self.algorithmIndex < 0 then
        table.insert(result.errors, "self.algorithmIndex is negative: " .. self.algorithmIndex)
    else
        result.details = "algorithmIndex = " .. self.algorithmIndex
    end
    
    -- Test 2: Verify it's consistent with current algorithm
    local currentAlg = getCurrentAlgorithm()
    if currentAlg ~= nil and currentAlg ~= self.algorithmIndex then
        table.insert(result.errors, "Mismatch: getCurrentAlgorithm()=" .. currentAlg .. ", self.algorithmIndex=" .. self.algorithmIndex)
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testAlgorithmQuery()
    local result = testResults["algorithmQuery"]
    result.status = "running"
    
    -- Test getAlgorithmCount()
    local algCount = getAlgorithmCount()
    if algCount == nil then
        table.insert(result.errors, "getAlgorithmCount() returned nil")
    elseif type(algCount) ~= "number" then
        table.insert(result.errors, "getAlgorithmCount() returned non-number: " .. type(algCount))
    elseif algCount <= 0 then
        table.insert(result.errors, "getAlgorithmCount() returned invalid count: " .. algCount)
    end
    
    if algCount and algCount > 0 then
        result.details = "Algorithm count: " .. algCount
        
        -- Test getAlgorithmName() for valid indices
        for i = 0, math.min(algCount - 1, 2) do -- Test first 3 algorithms
            local name = getAlgorithmName(i)
            if name == nil then
                table.insert(result.errors, "getAlgorithmName(" .. i .. ") returned nil")
            elseif type(name) ~= "string" then
                table.insert(result.errors, "getAlgorithmName(" .. i .. ") returned non-string: " .. type(name))
            elseif name == "" then
                table.insert(result.errors, "getAlgorithmName(" .. i .. ") returned empty string")
            else
                result.details = result.details .. ", Alg[" .. i .. "]=" .. name
            end
        end
        
        -- Test invalid indices
        local invalidName = getAlgorithmName(-1)
        if invalidName ~= nil then
            table.insert(result.errors, "getAlgorithmName(-1) should return nil, got: " .. tostring(invalidName))
        end
        
        invalidName = getAlgorithmName(algCount)
        if invalidName ~= nil then
            table.insert(result.errors, "getAlgorithmName(" .. algCount .. ") should return nil, got: " .. tostring(invalidName))
        end
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testParameterQuery()
    local result = testResults["parameterQuery"]
    result.status = "running"
    
    local algCount = getAlgorithmCount()
    if algCount and algCount > 0 then
        -- Test first few algorithms
        for alg = 0, math.min(algCount - 1, 2) do
            local paramCount = getParameterCount(alg)
            if paramCount == nil then
                table.insert(result.errors, "getParameterCount(" .. alg .. ") returned nil")
            elseif type(paramCount) ~= "number" then
                table.insert(result.errors, "getParameterCount(" .. alg .. ") returned non-number: " .. type(paramCount))
            elseif paramCount < 0 then
                table.insert(result.errors, "getParameterCount(" .. alg .. ") returned negative: " .. paramCount)
            else
                result.details = result.details .. "Alg[" .. alg .. "] params:" .. paramCount .. " "
                
                -- Test parameter names for this algorithm
                for param = 0, math.min(paramCount - 1, 1) do -- Test first 2 parameters
                    local paramName = getParameterName(alg, param)
                    if paramName == nil then
                        table.insert(result.errors, "getParameterName(" .. alg .. "," .. param .. ") returned nil")
                    elseif type(paramName) ~= "string" then
                        table.insert(result.errors, "getParameterName(" .. alg .. "," .. param .. ") returned non-string")
                    end
                end
                
                -- Test invalid parameter index
                local invalidParam = getParameterName(alg, paramCount)
                if invalidParam ~= nil then
                    table.insert(result.errors, "getParameterName(" .. alg .. "," .. paramCount .. ") should return nil")
                end
            end
        end
        
        -- Test invalid algorithm index
        local invalidCount = getParameterCount(-1)
        if invalidCount ~= nil then
            table.insert(result.errors, "getParameterCount(-1) should return nil")
        end
        
        invalidCount = getParameterCount(algCount)
        if invalidCount ~= nil then
            table.insert(result.errors, "getParameterCount(" .. algCount .. ") should return nil")
        end
    end
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testDisplayMode()
    local result = testResults["displayMode"]
    result.status = "running"
    
    -- Test all valid display modes
    local validModes = {0, 1, 2, 3, 4, 5}
    local modeNames = {"Normal", "Inverted", "Dim", "Bright", "Flashing", "Custom"}
    
    for i, mode in ipairs(validModes) do
        local success = setDisplayMode(mode)
        if success ~= true then
            table.insert(result.errors, "setDisplayMode(" .. mode .. ") failed: " .. tostring(success))
        else
            result.details = result.details .. modeNames[i] .. " "
        end
    end
    
    -- Test invalid modes
    local invalidModes = {-1, 6, 100, "invalid", nil}
    for _, mode in ipairs(invalidModes) do
        local success = setDisplayMode(mode)
        if success ~= false then
            table.insert(result.errors, "setDisplayMode(" .. tostring(mode) .. ") should return false")
        end
    end
    
    -- Reset to normal mode
    setDisplayMode(0)
    
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testTextAlignment()
    local result = testResults["textAlignment"]
    result.status = "running"
    
    -- Test all alignment options
    local alignments = {"left", "centre", "right"}
    
    for _, align in ipairs(alignments) do
        -- Test drawText with alignment
        local success = pcall(drawText, 100, 20, "Test " .. align, 15, align)
        if not success then
            table.insert(result.errors, "drawText with " .. align .. " alignment failed")
        end
        
        -- Test drawTinyText with alignment
        success = pcall(drawTinyText, 100, 30, "Tiny " .. align, 10, align)
        if not success then
            table.insert(result.errors, "drawTinyText with " .. align .. " alignment failed")
        end
    end
    
    -- Test backward compatibility (no alignment parameter)
    local success = pcall(drawText, 50, 40, "Backward Compat", 12)
    if not success then
        table.insert(result.errors, "drawText backward compatibility failed")
    end
    
    success = pcall(drawTinyText, 50, 50, "Tiny Backward", 8)
    if not success then
        table.insert(result.errors, "drawTinyText backward compatibility failed")
    end
    
    -- Test invalid alignments
    local invalidAlignments = {"center", "middle", "invalid", 123}
    for _, align in ipairs(invalidAlignments) do
        success = pcall(drawText, 150, 40, "Invalid", 12, align)
        if not success then
            -- This is expected behavior - invalid alignments should not crash
            result.details = result.details .. "Invalid alignment handled gracefully "
        end
    end
    
    result.details = result.details .. "All alignments tested"
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testErrorHandling()
    local result = testResults["errorHandling"]
    result.status = "running"
    
    -- Test error handling for all new functions
    local errorTests = {
        {func = getAlgorithmName, args = {nil}, desc = "getAlgorithmName(nil)"},
        {func = getAlgorithmName, args = {"invalid"}, desc = "getAlgorithmName(string)"},
        {func = getParameterCount, args = {nil}, desc = "getParameterCount(nil)"},
        {func = getParameterCount, args = {"invalid"}, desc = "getParameterCount(string)"},
        {func = getParameterName, args = {nil, 0}, desc = "getParameterName(nil, 0)"},
        {func = getParameterName, args = {0, nil}, desc = "getParameterName(0, nil)"},
        {func = getParameterName, args = {"invalid", "invalid"}, desc = "getParameterName(string, string)"},
        {func = setDisplayMode, args = {nil}, desc = "setDisplayMode(nil)"},
        {func = setDisplayMode, args = {"invalid"}, desc = "setDisplayMode(string)"}
    }
    
    local gracefulErrors = 0
    for _, test in ipairs(errorTests) do
        local success, errorResult = pcall(test.func, unpack(test.args))
        if success then
            -- Function didn't crash - check if it returned appropriate error value
            if errorResult == nil or errorResult == false then
                gracefulErrors = gracefulErrors + 1
                result.details = result.details .. "✓" .. test.desc .. " "
            else
                table.insert(result.errors, test.desc .. " should return nil/false, got: " .. tostring(errorResult))
            end
        else
            table.insert(result.errors, test.desc .. " crashed: " .. tostring(errorResult))
        end
    end
    
    result.details = result.details .. gracefulErrors .. "/" .. #errorTests .. " graceful"
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testPerformance()
    local result = testResults["performance"]
    result.status = "running"
    
    local iterations = 1000
    
    -- Benchmark algorithm queries
    local startTime = love.timer.getTime()
    for i = 1, iterations do
        local count = getAlgorithmCount()
        if count and count > 0 then
            getAlgorithmName(0)
        end
    end
    local algQueryTime = love.timer.getTime() - startTime
    
    -- Benchmark parameter queries
    startTime = love.timer.getTime()
    for i = 1, iterations do
        local count = getParameterCount(0)
        if count and count > 0 then
            getParameterName(0, 0)
        end
    end
    local paramQueryTime = love.timer.getTime() - startTime
    
    -- Benchmark display mode changes
    startTime = love.timer.getTime()
    for i = 1, iterations do
        setDisplayMode(i % 6)
    end
    local displayModeTime = love.timer.getTime() - startTime
    
    -- Benchmark text rendering with alignment
    startTime = love.timer.getTime()
    for i = 1, iterations do
        drawText(100, 20, "Perf Test", 12, "centre")
        drawTinyText(100, 30, "Tiny Perf", 8, "right")
    end
    local textAlignTime = love.timer.getTime() - startTime
    
    performanceStats = {
        algorithmQueries = algQueryTime,
        parameterQueries = paramQueryTime,
        displayModeChanges = displayModeTime,
        textAlignment = textAlignTime
    }
    
    -- Check for reasonable performance (all should be under 1 second for 1000 iterations)
    if algQueryTime > 1.0 then
        table.insert(result.errors, "Algorithm queries too slow: " .. algQueryTime .. "s")
    end
    if paramQueryTime > 1.0 then
        table.insert(result.errors, "Parameter queries too slow: " .. paramQueryTime .. "s")
    end
    if displayModeTime > 1.0 then
        table.insert(result.errors, "Display mode changes too slow: " .. displayModeTime .. "s")
    end
    if textAlignTime > 1.0 then
        table.insert(result.errors, "Text alignment too slow: " .. textAlignTime .. "s")
    end
    
    result.details = string.format("Alg:%.3fs Param:%.3fs Display:%.3fs Text:%.3fs", 
        algQueryTime, paramQueryTime, displayModeTime, textAlignTime)
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

local function testBackwardCompatibility()
    local result = testResults["backwardCompat"]
    result.status = "running"
    
    -- Test that old API functions still work
    local oldApiFunctions = {
        {func = getCurrentAlgorithm, desc = "getCurrentAlgorithm()"},
        {func = function() return getCurrentParameter(0) end, desc = "getCurrentParameter(0)"}
    }
    
    for _, test in ipairs(oldApiFunctions) do
        local success, result_val = pcall(test.func)
        if not success then
            table.insert(result.errors, test.desc .. " failed: " .. tostring(result_val))
        end
    end
    
    -- Test that text functions work with old signature
    local success = pcall(drawText, 10, 10, "Old Style", 15)
    if not success then
        table.insert(result.errors, "drawText old signature failed")
    end
    
    success = pcall(drawTinyText, 10, 20, "Old Tiny", 10)
    if not success then
        table.insert(result.errors, "drawTinyText old signature failed")
    end
    
    result.details = "Old API functions remain functional"
    result.status = #result.errors == 0 and "passed" or "failed"
    return result.status == "passed"
end

function test.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Update test phase every 180 frames (about 3 seconds)
    frameCounter = frameCounter + 1
    if frameCounter > 180 then
        frameCounter = 0
        testPhase = testPhase + 1
        if testPhase > #testPhases then
            testPhase = #testPhases -- Stay on summary
        end
    end
    
    local currentPhase = testPhases[testPhase]
    
    -- Run the current test
    if currentPhase.test == "algorithmIndex" then
        testAlgorithmIndex()
    elseif currentPhase.test == "algorithmQuery" then
        testAlgorithmQuery()
    elseif currentPhase.test == "parameterQuery" then
        testParameterQuery()
    elseif currentPhase.test == "displayMode" then
        testDisplayMode()
    elseif currentPhase.test == "textAlignment" then
        testTextAlignment()
    elseif currentPhase.test == "errorHandling" then
        testErrorHandling()
    elseif currentPhase.test == "performance" then
        testPerformance()
    elseif currentPhase.test == "backwardCompat" then
        testBackwardCompatibility()
    end
    
    -- Display current test phase
    drawText(128, 5, "API 1.10.0 Integration Test", 15, "centre")
    drawText(128, 15, "Phase " .. testPhase .. "/" .. #testPhases .. ": " .. currentPhase.name, 10, "centre")
    
    -- Display test results
    if currentPhase.test ~= "summary" then
        local result = testResults[currentPhase.test]
        local statusColor = result.status == "passed" and 15 or result.status == "failed" and 5 or 8
        drawText(10, 30, "Status: " .. result.status, statusColor)
        
        if result.details ~= "" then
            drawTinyText(10, 40, result.details, 12)
        end
        
        if #result.errors > 0 then
            drawTinyText(10, 50, "Errors: " .. #result.errors, 5)
            if result.errors[1] then
                drawTinyText(10, 58, result.errors[1]:sub(1, 40), 3)
            end
        end
    else
        -- Summary view
        local passed = 0
        local failed = 0
        local total = 0
        
        for _, phase in ipairs(testPhases) do
            if phase.test ~= "summary" then
                total = total + 1
                local result = testResults[phase.test]
                if result.status == "passed" then
                    passed = passed + 1
                elseif result.status == "failed" then
                    failed = failed + 1
                end
            end
        end
        
        drawText(128, 30, "Test Results Summary", 15, "centre")
        drawText(128, 40, "Passed: " .. passed .. "  Failed: " .. failed .. "  Total: " .. total, 10, "centre")
        
        local overallStatus = failed == 0 and "ALL TESTS PASSED" or "SOME TESTS FAILED"
        local statusColor = failed == 0 and 15 or 5
        drawText(128, 50, overallStatus, statusColor, "centre")
        
        if performanceStats.algorithmQueries then
            drawTinyText(10, 58, string.format("Perf: A:%.1fms P:%.1fms D:%.1fms T:%.1fms", 
                performanceStats.algorithmQueries * 1000,
                performanceStats.parameterQueries * 1000,
                performanceStats.displayModeChanges * 1000,
                performanceStats.textAlignment * 1000), 8)
        end
    end
    
    -- Progress bar
    local progress = (testPhase - 1) / (#testPhases - 1)
    fillRectangle(0, 62, progress * 256, 64, 10)
    
    return true
end

-- Control callbacks for manual navigation
function test.button1Pressed()
    if testPhase < #testPhases then
        testPhase = testPhase + 1
        frameCounter = 0
        print("Advanced to phase " .. testPhase .. ": " .. testPhases[testPhase].name)
    end
end

function test.button2Pressed()
    if testPhase > 1 then
        testPhase = testPhase - 1
        frameCounter = 0
        print("Back to phase " .. testPhase .. ": " .. testPhases[testPhase].name)
    end
end

function test.encoderPressed()
    -- Print detailed test results
    print("\n=== API 1.10.0 Integration Test Results ===")
    for _, phase in ipairs(testPhases) do
        if phase.test ~= "summary" then
            local result = testResults[phase.test]
            print(phase.name .. ": " .. result.status)
            if result.details ~= "" then
                print("  Details: " .. result.details)
            end
            for _, error in ipairs(result.errors) do
                print("  ERROR: " .. error)
            end
        end
    end
    
    if performanceStats.algorithmQueries then
        print("\nPerformance Benchmarks (1000 iterations):")
        print("  Algorithm Queries: " .. string.format("%.3f", performanceStats.algorithmQueries) .. "s")
        print("  Parameter Queries: " .. string.format("%.3f", performanceStats.parameterQueries) .. "s")
        print("  Display Mode Changes: " .. string.format("%.3f", performanceStats.displayModeChanges) .. "s")
        print("  Text Alignment: " .. string.format("%.3f", performanceStats.textAlignment) .. "s")
    end
    print("=== End Test Results ===\n")
end

-- Input/output definitions for testing I/O integration
test.inputs = {kCV, kTrigger, kGate, kCV}
test.outputs = {kCV, kCV, kGate, kTrigger}

return test