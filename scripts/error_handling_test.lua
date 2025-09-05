-- error_handling_test.lua
-- Comprehensive error handling and edge case testing for API 1.10.0
-- Tests boundary conditions, invalid inputs, and graceful degradation

local test = {}

-- Test state
local testIndex = 1
local frameCounter = 0
local errorResults = {}

-- Test categories
local errorTestCategories = {
    {name = "Algorithm Index Errors", test = "algorithmIndexErrors"},
    {name = "Algorithm Query Errors", test = "algorithmQueryErrors"},
    {name = "Parameter Query Errors", test = "parameterQueryErrors"},
    {name = "Display Mode Errors", test = "displayModeErrors"},
    {name = "Text Alignment Errors", test = "textAlignmentErrors"},
    {name = "Type Safety Tests", test = "typeSafetyTests"},
    {name = "Boundary Condition Tests", test = "boundaryTests"},
    {name = "Memory Safety Tests", test = "memorySafetyTests"}
}

function test.init()
    print("=== Error Handling & Edge Case Test Suite ===")
    
    errorResults = {}
    testIndex = 1
    frameCounter = 0
    
    -- Initialize results
    for _, category in ipairs(errorTestCategories) do
        errorResults[category.test] = {
            name = category.name,
            passed = 0,
            failed = 0,
            errors = {},
            details = ""
        }
    end
    
    print("Initialized " .. #errorTestCategories .. " error test categories")
end

function test.process(inputs, outputs)
    -- Simple pass-through for I/O testing
    for i = 1, 4 do
        outputs[i] = inputs[i] or 0
    end
end

-- Test algorithm index edge cases
local function testAlgorithmIndexErrors()
    local result = errorResults["algorithmIndexErrors"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test 1: Access algorithmIndex when it might not exist
    testsTotal = testsTotal + 1
    local success, value = pcall(function() return self.algorithmIndex end)
    if success then
        if value ~= nil and type(value) == "number" then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "algorithmIndex exists but has invalid type: " .. type(value))
        end
    else
        table.insert(result.errors, "Failed to access self.algorithmIndex: " .. tostring(value))
    end
    
    -- Test 2: Check consistency across multiple accesses
    testsTotal = testsTotal + 1
    local firstAccess = self.algorithmIndex
    local secondAccess = self.algorithmIndex
    if firstAccess == secondAccess then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "algorithmIndex inconsistent: " .. tostring(firstAccess) .. " vs " .. tostring(secondAccess))
    end
    
    -- Test 3: Check if algorithmIndex changes appropriately
    testsTotal = testsTotal + 1
    local beforeIndex = self.algorithmIndex
    -- Can't directly test algorithm changes in emulator, but verify it doesn't randomly change
    local afterIndex = self.algorithmIndex
    if beforeIndex == afterIndex then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "algorithmIndex changed unexpectedly during test")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test algorithm query error handling
local function testAlgorithmQueryErrors()
    local result = errorResults["algorithmQueryErrors"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test getAlgorithmCount error handling
    testsTotal = testsTotal + 1
    local success, count = pcall(getAlgorithmCount)
    if success and (count == nil or (type(count) == "number" and count >= 0)) then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "getAlgorithmCount() invalid result: " .. tostring(count))
    end
    
    if count and count > 0 then
        -- Test invalid indices for getAlgorithmName
        local invalidIndices = {-1, -100, count, count + 1, count + 100}
        for _, index in ipairs(invalidIndices) do
            testsTotal = testsTotal + 1
            local success, name = pcall(getAlgorithmName, index)
            if success and name == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getAlgorithmName(" .. index .. ") should return nil, got: " .. tostring(name))
            end
        end
        
        -- Test invalid argument types
        local invalidTypes = {nil, "string", {}, function() end, true}
        for _, invalidArg in ipairs(invalidTypes) do
            testsTotal = testsTotal + 1
            local success, name = pcall(getAlgorithmName, invalidArg)
            if success and name == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getAlgorithmName(" .. type(invalidArg) .. ") should return nil")
            end
        end
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test parameter query error handling
local function testParameterQueryErrors()
    local result = errorResults["parameterQueryErrors"]
    local testsPassed = 0
    local testsTotal = 0
    
    local algCount = getAlgorithmCount()
    if algCount and algCount > 0 then
        -- Test invalid algorithm indices for parameter functions
        local invalidAlgIndices = {-1, -100, algCount, algCount + 1, algCount + 100}
        for _, algIndex in ipairs(invalidAlgIndices) do
            -- Test getParameterCount with invalid algorithm
            testsTotal = testsTotal + 1
            local success, count = pcall(getParameterCount, algIndex)
            if success and count == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getParameterCount(" .. algIndex .. ") should return nil")
            end
            
            -- Test getParameterName with invalid algorithm
            testsTotal = testsTotal + 1
            local success, name = pcall(getParameterName, algIndex, 0)
            if success and name == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getParameterName(" .. algIndex .. ",0) should return nil")
            end
        end
        
        -- Test with first valid algorithm
        local paramCount = getParameterCount(0)
        if paramCount and paramCount > 0 then
            -- Test invalid parameter indices
            local invalidParamIndices = {-1, -100, paramCount, paramCount + 1, paramCount + 100}
            for _, paramIndex in ipairs(invalidParamIndices) do
                testsTotal = testsTotal + 1
                local success, name = pcall(getParameterName, 0, paramIndex)
                if success and name == nil then
                    testsPassed = testsPassed + 1
                else
                    table.insert(result.errors, "getParameterName(0," .. paramIndex .. ") should return nil")
                end
            end
        end
        
        -- Test invalid argument types
        local invalidTypes = {nil, "string", {}, function() end, true}
        for _, invalidArg in ipairs(invalidTypes) do
            testsTotal = testsTotal + 1
            local success, count = pcall(getParameterCount, invalidArg)
            if success and count == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getParameterCount(" .. type(invalidArg) .. ") should return nil")
            end
            
            testsTotal = testsTotal + 1
            local success, name = pcall(getParameterName, invalidArg, 0)
            if success and name == nil then
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, "getParameterName(" .. type(invalidArg) .. ",0) should return nil")
            end
        end
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test display mode error handling
local function testDisplayModeErrors()
    local result = errorResults["displayModeErrors"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test invalid display modes
    local invalidModes = {-1, -100, 6, 7, 100, 999}
    for _, mode in ipairs(invalidModes) do
        testsTotal = testsTotal + 1
        local success, result_val = pcall(setDisplayMode, mode)
        if success and result_val == false then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "setDisplayMode(" .. mode .. ") should return false")
        end
    end
    
    -- Test invalid argument types
    local invalidTypes = {nil, "string", {}, function() end, true}
    for _, invalidArg in ipairs(invalidTypes) do
        testsTotal = testsTotal + 1
        local success, result_val = pcall(setDisplayMode, invalidArg)
        if success and result_val == false then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "setDisplayMode(" .. type(invalidArg) .. ") should return false")
        end
    end
    
    -- Test valid modes still work
    local validModes = {0, 1, 2, 3, 4, 5}
    for _, mode in ipairs(validModes) do
        testsTotal = testsTotal + 1
        local success, result_val = pcall(setDisplayMode, mode)
        if success and result_val == true then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "setDisplayMode(" .. mode .. ") should return true")
        end
    end
    
    -- Reset to normal mode
    setDisplayMode(0)
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test text alignment error handling
local function testTextAlignmentErrors()
    local result = errorResults["textAlignmentErrors"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test invalid alignments (should not crash)
    local invalidAlignments = {"center", "middle", "top", "bottom", "invalid", 123, {}, nil}
    for _, alignment in ipairs(invalidAlignments) do
        testsTotal = testsTotal + 1
        local success = pcall(drawText, 100, 20, "Test", 12, alignment)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "drawText with invalid alignment crashed: " .. tostring(alignment))
        end
        
        testsTotal = testsTotal + 1
        local success = pcall(drawTinyText, 100, 30, "Test", 8, alignment)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "drawTinyText with invalid alignment crashed: " .. tostring(alignment))
        end
    end
    
    -- Test with extreme coordinates
    local extremeCoords = {{-1000, -1000}, {5000, 5000}, {0, -100}, {300, 100}}
    for _, coord in ipairs(extremeCoords) do
        testsTotal = testsTotal + 1
        local success = pcall(drawText, coord[1], coord[2], "Test", 12, "centre")
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "drawText with extreme coords crashed: " .. coord[1] .. "," .. coord[2])
        end
    end
    
    -- Test with very long text
    testsTotal = testsTotal + 1
    local longText = string.rep("A", 1000)
    local success = pcall(drawText, 50, 40, longText, 12, "left")
    if success then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "drawText with long text crashed")
    end
    
    -- Test with special characters
    testsTotal = testsTotal + 1
    local specialText = "!@#$%^&*()[]{}|\\:;\"'<>,.?/`~"
    local success = pcall(drawText, 50, 50, specialText, 10, "right")
    if success then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "drawText with special characters crashed")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test type safety
local function testTypeSafetyTests()
    local result = errorResults["typeSafetyTests"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test that functions handle type mismatches gracefully
    local functions = {
        {func = getAlgorithmName, args = {{nil}, {"string"}, {{}}}, name = "getAlgorithmName"},
        {func = getParameterCount, args = {{nil}, {"string"}, {{}}}, name = "getParameterCount"},
        {func = getParameterName, args = {{nil, 0}, {0, nil}, {"string", "string"}}, name = "getParameterName"},
        {func = setDisplayMode, args = {{nil}, {"string"}, {{}}}, name = "setDisplayMode"}
    }
    
    for _, funcTest in ipairs(functions) do
        for _, args in ipairs(funcTest.args) do
            testsTotal = testsTotal + 1
            local success, result_val = pcall(funcTest.func, unpack(args))
            if success then
                -- Function should return nil/false for invalid types, not crash
                testsPassed = testsPassed + 1
            else
                table.insert(result.errors, funcTest.name .. " crashed with invalid types")
            end
        end
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test boundary conditions
local function testBoundaryTests()
    local result = errorResults["boundaryTests"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test extreme values
    local extremeValues = {
        math.huge,
        -math.huge,
        0/0, -- NaN
        2^31,
        -2^31,
        2^53,
        -2^53
    }
    
    for _, value in ipairs(extremeValues) do
        -- Test with algorithm functions
        testsTotal = testsTotal + 1
        local success = pcall(getAlgorithmName, value)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "getAlgorithmName crashed with extreme value: " .. tostring(value))
        end
        
        testsTotal = testsTotal + 1
        local success = pcall(setDisplayMode, value)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "setDisplayMode crashed with extreme value: " .. tostring(value))
        end
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

-- Test memory safety
local function testMemorySafetyTests()
    local result = errorResults["memorySafetyTests"]
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test repeated calls to ensure no memory leaks or corruption
    testsTotal = testsTotal + 1
    local initialMemory = collectgarbage("count")
    for i = 1, 100 do
        local count = getAlgorithmCount()
        if count and count > 0 then
            getAlgorithmName(0)
            getParameterCount(0)
            getParameterName(0, 0)
        end
        setDisplayMode(i % 6)
        drawText(100, 20, "Memory Test " .. i, 12, "centre")
    end
    collectgarbage("collect")
    local finalMemory = collectgarbage("count")
    
    -- Check if memory usage grew excessively (allow for some growth)
    if finalMemory - initialMemory < 1000 then -- Less than 1MB growth
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "Possible memory leak: " .. (finalMemory - initialMemory) .. "KB increase")
    end
    
    -- Test string handling doesn't cause corruption
    testsTotal = testsTotal + 1
    local testStrings = {}
    for i = 1, 100 do
        local str = "Test string " .. i
        table.insert(testStrings, str)
        drawText(50, 30, str, 10, "left")
    end
    
    -- Verify strings are still intact
    local stringsIntact = true
    for i, str in ipairs(testStrings) do
        if str ~= "Test string " .. i then
            stringsIntact = false
            break
        end
    end
    
    if stringsIntact then
        testsPassed = testsPassed + 1
    else
        table.insert(result.errors, "String corruption detected")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.details = testsPassed .. "/" .. testsTotal .. " tests passed"
    
    return testsPassed == testsTotal
end

function test.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Auto-advance every 120 frames (2 seconds)
    frameCounter = frameCounter + 1
    if frameCounter > 120 then
        frameCounter = 0
        testIndex = testIndex + 1
        if testIndex > #errorTestCategories then
            testIndex = #errorTestCategories -- Stay on last test
        end
    end
    
    local currentTest = errorTestCategories[testIndex]
    
    -- Run the current test
    local testFunction = {
        algorithmIndexErrors = testAlgorithmIndexErrors,
        algorithmQueryErrors = testAlgorithmQueryErrors,
        parameterQueryErrors = testParameterQueryErrors,
        displayModeErrors = testDisplayModeErrors,
        textAlignmentErrors = testTextAlignmentErrors,
        typeSafetyTests = testTypeSafetyTests,
        boundaryTests = testBoundaryTests,
        memorySafetyTests = testMemorySafetyTests
    }
    
    if testFunction[currentTest.test] then
        testFunction[currentTest.test]()
    end
    
    -- Display current test
    drawText(128, 5, "Error Handling Test Suite", 15, "centre")
    drawText(128, 15, "Test " .. testIndex .. "/" .. #errorTestCategories .. ": " .. currentTest.name, 10, "centre")
    
    -- Display results
    local result = errorResults[currentTest.test]
    local totalTests = result.passed + result.failed
    local passRate = totalTests > 0 and (result.passed / totalTests * 100) or 0
    
    local statusColor = result.failed == 0 and 15 or 5
    drawText(10, 30, "Results: " .. result.passed .. " passed, " .. result.failed .. " failed", statusColor)
    drawText(10, 40, "Pass Rate: " .. string.format("%.1f", passRate) .. "%", statusColor)
    
    if result.details ~= "" then
        drawTinyText(10, 50, result.details, 12)
    end
    
    if #result.errors > 0 then
        drawTinyText(10, 58, "Error: " .. (result.errors[1] or "Unknown"):sub(1, 35), 5)
    end
    
    -- Progress bar
    local progress = (testIndex - 1) / (#errorTestCategories - 1)
    fillRectangle(0, 62, progress * 256, 64, 10)
    
    return true
end

-- Control callbacks
function test.button1Pressed()
    if testIndex < #errorTestCategories then
        testIndex = testIndex + 1
        frameCounter = 0
        print("Advanced to test: " .. errorTestCategories[testIndex].name)
    end
end

function test.button2Pressed()
    if testIndex > 1 then
        testIndex = testIndex - 1
        frameCounter = 0
        print("Back to test: " .. errorTestCategories[testIndex].name)
    end
end

function test.encoderPressed()
    -- Print detailed error results
    print("\n=== Error Handling Test Results ===")
    local totalPassed = 0
    local totalFailed = 0
    
    for _, category in ipairs(errorTestCategories) do
        local result = errorResults[category.test]
        print(category.name .. ": " .. result.passed .. " passed, " .. result.failed .. " failed")
        totalPassed = totalPassed + result.passed
        totalFailed = totalFailed + result.failed
        
        for _, error in ipairs(result.errors) do
            print("  ERROR: " .. error)
        end
    end
    
    print("\nOverall: " .. totalPassed .. " passed, " .. totalFailed .. " failed")
    local overallRate = (totalPassed + totalFailed) > 0 and (totalPassed / (totalPassed + totalFailed) * 100) or 0
    print("Overall Pass Rate: " .. string.format("%.1f", overallRate) .. "%")
    print("=== End Error Handling Results ===\n")
end

-- Input/output definitions
test.inputs = {kCV, kTrigger, kGate, kCV}
test.outputs = {kCV, kCV, kGate, kTrigger}

return test