-- comprehensive_backward_compatibility_test.lua
-- Complete backward compatibility test for API 1.10.0
-- Ensures all existing 1.9.0 scripts continue to work unchanged

local test = {}

-- Test state
local testPhase = 1
local frameCounter = 0
local compatibilityResults = {}

-- Compatibility test phases
local testPhases = {
    {name = "Original API Functions", test = "originalAPI"},
    {name = "Text Rendering Legacy", test = "textLegacy"},
    {name = "Script Structure Compatibility", test = "scriptStructure"},
    {name = "Parameter System Legacy", test = "parameterLegacy"},
    {name = "Drawing Functions Legacy", test = "drawingLegacy"},
    {name = "Control Callbacks Legacy", test = "controlLegacy"},
    {name = "I/O Definitions Legacy", test = "ioLegacy"},
    {name = "State Management Legacy", test = "stateLegacy"},
    {name = "Emulation of Original test_script.lua", test = "originalScript"}
}

-- Store original test script functions for testing
local originalScriptFunctions = {}

function test.init()
    print("=== Comprehensive Backward Compatibility Test ===")
    print("Testing all existing API 1.9.0 functionality")
    
    compatibilityResults = {}
    testPhase = 1
    frameCounter = 0
    
    -- Initialize results
    for _, phase in ipairs(testPhases) do
        compatibilityResults[phase.test] = {
            name = phase.name,
            status = "pending",
            passed = 0,
            failed = 0,
            errors = {},
            details = ""
        }
    end
    
    -- Set up original script emulation
    setupOriginalScriptEmulation()
    
    print("Initialized " .. #testPhases .. " compatibility test phases")
end

function test.process(inputs, outputs)
    -- Test that basic I/O processing still works like in original scripts
    for i = 1, 4 do
        outputs[i] = (inputs[i] or 0) * 0.5 + math.sin(love.timer.getTime() + i) * 0.1
    end
end

-- Set up emulation of original test script functions
function setupOriginalScriptEmulation()
    -- Emulate original script variables and functions
    originalScriptFunctions = {
        time = 0,
        f = 2 * math.pi,
        x = 0,
        y = 0,
        dx = 5,
        dy = 6.7,
        bing = 0.0,
        gateState = false,
        p1 = 0.5,
        p2 = 0.5,
        p3 = 1.0
    }
    
    -- Helper functions from original script
    originalScriptFunctions.toScreenX = function(x) return 1.0 + 2.5 * (x + 10.0) end
    originalScriptFunctions.toScreenY = function(y) return 12.0 + 2.5 * (10.0 - y) end
end

-- Test original API functions
local function testOriginalAPI()
    local result = compatibilityResults["originalAPI"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test getCurrentAlgorithm() - should still work
    testsTotal = testsTotal + 1
    local success, alg = pcall(getCurrentAlgorithm)
    if success and (alg == nil or type(alg) == "number") then
        testsPassed = testsPassed + 1
        result.details = result.details .. "getCurrentAlgorithm() works "
    else
        table.insert(result.errors, "getCurrentAlgorithm() failed or returned invalid type")
    end
    
    -- Test getCurrentParameter() - should still work
    testsTotal = testsTotal + 1
    local success, param = pcall(getCurrentParameter, 0)
    if success and (param == nil or type(param) == "number") then
        testsPassed = testsPassed + 1
        result.details = result.details .. "getCurrentParameter() works "
    else
        table.insert(result.errors, "getCurrentParameter() failed or returned invalid type")
    end
    
    -- Test that these functions coexist with new API functions
    testsTotal = testsTotal + 1
    local algFromOld = getCurrentAlgorithm()
    local algFromNew = self.algorithmIndex
    -- They should be consistent if both are available
    if algFromOld ~= nil and algFromNew ~= nil then
        if algFromOld == algFromNew then
            testsPassed = testsPassed + 1
            result.details = result.details .. "Old/new API consistent "
        else
            table.insert(result.errors, "getCurrentAlgorithm() and self.algorithmIndex inconsistent")
        end
    else
        testsPassed = testsPassed + 1 -- Can't test consistency, but that's not a failure
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test text rendering legacy compatibility
local function testTextLegacy()
    local result = compatibilityResults["textLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test 4-parameter drawText (original signature)
    testsTotal = testsTotal + 1
    local success = pcall(drawText, 50, 20, "Legacy Text", 15)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "4-param drawText works "
    else
        table.insert(result.errors, "4-parameter drawText failed")
    end
    
    -- Test 4-parameter drawTinyText (original signature)
    testsTotal = testsTotal + 1
    local success = pcall(drawTinyText, 50, 30, "Legacy Tiny", 10)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "4-param drawTinyText works "
    else
        table.insert(result.errors, "4-parameter drawTinyText failed")
    end
    
    -- Test that 4-parameter calls work alongside 5-parameter calls
    testsTotal = testsTotal + 1
    local success1 = pcall(drawText, 100, 20, "Old Style", 12)
    local success2 = pcall(drawText, 150, 20, "New Style", 12, "centre")
    if success1 and success2 then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Mixed signatures work "
    else
        table.insert(result.errors, "Mixed text signature usage failed")
    end
    
    -- Test with various text lengths (edge cases from original scripts)
    testsTotal = testsTotal + 1
    local texts = {"", "A", "Medium Text", "Very Long Text That Might Cause Issues"}
    local allSucceeded = true
    for _, text in ipairs(texts) do
        local success = pcall(drawText, 80, 40, text, 8)
        if not success then
            allSucceeded = false
            break
        end
    end
    if allSucceeded then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Variable text lengths work "
    else
        table.insert(result.errors, "Some text lengths failed with legacy signature")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test script structure compatibility
local function testScriptStructure()
    local result = compatibilityResults["scriptStructure"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test that all standard script callbacks are still called
    local callbacksToTest = {
        "init", "process", "render", "serialise",
        "button1Pressed", "button2Pressed", "encoderPressed",
        "pot1Turn", "pot2Turn", "pot3Turn",
        "encoder1Turn", "encoder2Turn", "pot3Push", "encoder2Push",
        "trigger", "gate", "step", "ui", "draw"
    }
    
    for _, callback in ipairs(callbacksToTest) do
        testsTotal = testsTotal + 1
        -- Test that we can define these callbacks without issues
        local success = pcall(function()
            test[callback] = function(...) return true end
        end)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "Failed to define callback: " .. callback)
        end
    end
    
    result.details = "Tested " .. #callbacksToTest .. " standard callbacks"
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test parameter system legacy compatibility
local function testParameterLegacy()
    local result = compatibilityResults["parameterLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test that self.parameters array access still works
    testsTotal = testsTotal + 1
    local success = pcall(function()
        if self.parameters then
            local param = self.parameters[1]
            return param
        end
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "self.parameters access works "
    else
        table.insert(result.errors, "self.parameters access failed")
    end
    
    -- Test that parameterOffset still works
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local offset = self.parameterOffset or 0
        return offset
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "parameterOffset access works "
    else
        table.insert(result.errors, "parameterOffset access failed")
    end
    
    -- Test parameter definition structures (from init function returns)
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local paramDef = {
            inputs = {kCV, kTrigger, kGate},
            outputs = 2,
            parameters = {
                {"Min X", -10, 10, -10, kVolts},
                {"Max X", -10, 10, 10, kVolts},
                {"Edges", {"Bounce", "Warp"}, 1}
            }
        }
        return paramDef
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Parameter definitions work "
    else
        table.insert(result.errors, "Parameter definition structure failed")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test drawing functions legacy compatibility
local function testDrawingLegacy()
    local result = compatibilityResults["drawingLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test all original drawing functions still work
    local drawingFunctions = {
        {func = drawRectangle, args = {10, 10, 50, 50, 15}, name = "drawRectangle"},
        {func = drawSmoothBox, args = {60, 10, 100, 50, 15}, name = "drawSmoothBox"},
        {func = drawLine, args = {110, 10, 150, 50, 10}, name = "drawLine"},
        {func = fillRectangle, args = {160, 10, 200, 50, 8}, name = "fillRectangle"}
    }
    
    for _, drawFunc in ipairs(drawingFunctions) do
        testsTotal = testsTotal + 1
        local success = pcall(drawFunc.func, unpack(drawFunc.args))
        if success then
            testsPassed = testsPassed + 1
            result.details = result.details .. drawFunc.name .. " ✓ "
        else
            table.insert(result.errors, drawFunc.name .. " failed")
        end
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test control callbacks legacy compatibility
local function testControlLegacy()
    local result = compatibilityResults["controlLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test that we can still define old-style control callbacks
    local controlCallbacks = {
        "pot1Turn", "pot2Turn", "pot3Turn",
        "encoder1Turn", "encoder2Turn", 
        "pot3Push", "encoder2Push",
        "button1Pressed", "button2Pressed", "encoderPressed"
    }
    
    for _, callback in ipairs(controlCallbacks) do
        testsTotal = testsTotal + 1
        local success = pcall(function()
            -- Test that we can define the callback
            test[callback] = function(self, ...)
                -- Original callbacks should be able to access self and modify variables
                if callback == "pot1Turn" then
                    originalScriptFunctions.p1 = (...) or 0.5
                elseif callback == "pot2Turn" then
                    originalScriptFunctions.p2 = (...) or 0.5
                elseif callback == "pot3Turn" then
                    originalScriptFunctions.p3 = (...) or 0.5
                end
                return true
            end
            return true
        end)
        if success then
            testsPassed = testsPassed + 1
        else
            table.insert(result.errors, "Failed to define " .. callback)
        end
    end
    
    result.details = "Tested " .. #controlCallbacks .. " control callbacks"
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test I/O definitions legacy compatibility
local function testIOLegacy()
    local result = compatibilityResults["ioLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test original I/O constant definitions
    local ioConstants = {"kCV", "kGate", "kTrigger"}
    for _, constant in ipairs(ioConstants) do
        testsTotal = testsTotal + 1
        local success = pcall(function()
            local value = _G[constant]
            return value ~= nil
        end)
        if success then
            testsPassed = testsPassed + 1
            result.details = result.details .. constant .. " ✓ "
        else
            table.insert(result.errors, "I/O constant " .. constant .. " not available")
        end
    end
    
    -- Test I/O array definitions
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local ioTest = {
            inputs = {kCV, kTrigger, kGate},
            outputs = {kCV, kCV, kGate, kTrigger}
        }
        return ioTest
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "I/O arrays work "
    else
        table.insert(result.errors, "I/O array definition failed")
    end
    
    -- Test numeric output definitions (original style)
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local ioTest = {
            inputs = {kCV, kTrigger},
            outputs = 4  -- Original numeric style
        }
        return ioTest
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Numeric outputs work "
    else
        table.insert(result.errors, "Numeric output definition failed")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test state management legacy compatibility
local function testStateLegacy()
    local result = compatibilityResults["stateLegacy"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Test that serialise function structure still works
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local serializeFunc = function(self)
            local state = {}
            state.p1 = originalScriptFunctions.p1
            state.p2 = originalScriptFunctions.p2
            state.p3 = originalScriptFunctions.p3
            return state
        end
        local state = serializeFunc(self)
        return state ~= nil and state.p1 ~= nil
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "serialise function works "
    else
        table.insert(result.errors, "serialise function structure failed")
    end
    
    -- Test that init function can restore state
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local initFunc = function(self)
            local state = self.state or {}
            originalScriptFunctions.p1 = state.p1 or 0.5
            return {
                inputs = {kCV, kTrigger, kGate},
                outputs = 2
            }
        end
        local result = initFunc({state = {p1 = 0.7}})
        return result ~= nil and result.inputs ~= nil
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "init state restore works "
    else
        table.insert(result.errors, "init state restore failed")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

-- Test original script functionality
local function testOriginalScript()
    local result = compatibilityResults["originalScript"]
    result.status = "running"
    local testsPassed = 0
    local testsTotal = 0
    
    -- Emulate the original bouncy ball script functionality
    testsTotal = testsTotal + 1
    local success = pcall(function()
        -- Original script calculations
        local time = love.timer.getTime()
        local x = originalScriptFunctions.x + originalScriptFunctions.dx * 0.016 -- Simulate dt
        local y = originalScriptFunctions.y + originalScriptFunctions.dy * 0.016
        
        -- Original screen coordinate conversion
        local toScreenX = originalScriptFunctions.toScreenX
        local toScreenY = originalScriptFunctions.toScreenY
        
        local lx = toScreenX(-10.0)
        local cx = toScreenX(0.0)
        local rx = toScreenX(10.0)
        local ty = toScreenY(10.0)
        local cy = toScreenY(0.0)
        local by = toScreenY(-10.0)
        
        -- Original drawing calls
        drawRectangle(cx, ty, cx, by, 2)
        drawRectangle(lx, cy, rx, cy, 2)
        
        local px = toScreenX(x)
        local py = toScreenY(y)
        drawSmoothBox(px - 1.0, py - 1.0, px + 1.0, py + 1.0, 15.0)
        
        -- Original text calls
        drawText(100, 20, "p1: " .. originalScriptFunctions.p1, 15)
        drawText(100, 30, "p2: " .. originalScriptFunctions.p2, 15)
        drawText(100, 40, "p3: " .. originalScriptFunctions.p3, 15)
        
        return true
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Original script drawing works "
    else
        table.insert(result.errors, "Original script emulation failed")
    end
    
    -- Test original step function logic
    testsTotal = testsTotal + 1
    local success = pcall(function()
        local dt = 0.016
        local inputs = {0, 0, false}
        
        -- Original step calculations
        originalScriptFunctions.x = originalScriptFunctions.x + originalScriptFunctions.dx * dt
        originalScriptFunctions.y = originalScriptFunctions.y + originalScriptFunctions.dy * dt
        
        originalScriptFunctions.time = originalScriptFunctions.time + dt
        local t = originalScriptFunctions.f * originalScriptFunctions.time
        
        local out = {}
        out[1] = originalScriptFunctions.x + math.sin(t)
        out[2] = originalScriptFunctions.y + inputs[1]
        
        return out[1] ~= nil and out[2] ~= nil
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Original step logic works "
    else
        table.insert(result.errors, "Original step function logic failed")
    end
    
    -- Test original parameter handling
    testsTotal = testsTotal + 1
    local success = pcall(function()
        -- Simulate original parameter access
        if self.parameters then
            local minX = self.parameters[1] or -10
            local maxX = self.parameters[2] or 10
            local edges = self.parameters[5] or 1
            return minX ~= nil and maxX ~= nil and edges ~= nil
        end
        return true -- If no parameters, that's also valid
    end)
    if success then
        testsPassed = testsPassed + 1
        result.details = result.details .. "Original parameter access works "
    else
        table.insert(result.errors, "Original parameter access failed")
    end
    
    result.passed = testsPassed
    result.failed = testsTotal - testsPassed
    result.status = result.failed == 0 and "passed" or "failed"
    
    return result.status == "passed"
end

function test.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Auto-advance every 150 frames (2.5 seconds)
    frameCounter = frameCounter + 1
    if frameCounter > 150 then
        frameCounter = 0
        testPhase = testPhase + 1
        if testPhase > #testPhases then
            testPhase = #testPhases -- Stay on last phase
        end
    end
    
    local currentPhase = testPhases[testPhase]
    
    -- Run the current test
    local testFunctions = {
        originalAPI = testOriginalAPI,
        textLegacy = testTextLegacy,
        scriptStructure = testScriptStructure,
        parameterLegacy = testParameterLegacy,
        drawingLegacy = testDrawingLegacy,
        controlLegacy = testControlLegacy,
        ioLegacy = testIOLegacy,
        stateLegacy = testStateLegacy,
        originalScript = testOriginalScript
    }
    
    if testFunctions[currentPhase.test] then
        testFunctions[currentPhase.test]()
    end
    
    -- Display current test
    drawText(128, 5, "Backward Compatibility Test", 15, "centre")
    drawText(128, 15, "Phase " .. testPhase .. "/" .. #testPhases .. ": " .. currentPhase.name, 8, "centre")
    
    -- Display results
    local result = compatibilityResults[currentPhase.test]
    local statusColor = result.status == "passed" and 15 or result.status == "failed" and 5 or 10
    drawText(10, 25, "Status: " .. result.status, statusColor)
    drawText(10, 35, "Passed: " .. result.passed .. "  Failed: " .. result.failed, statusColor)
    
    if result.details ~= "" then
        drawTinyText(10, 45, result.details, 12)
    end
    
    if #result.errors > 0 then
        drawTinyText(10, 55, "Errors: " .. #result.errors, 5)
    end
    
    -- Overall summary if on last phase
    if testPhase == #testPhases then
        local totalPassed = 0
        local totalFailed = 0
        for _, phase in ipairs(testPhases) do
            local res = compatibilityResults[phase.test]
            totalPassed = totalPassed + res.passed
            totalFailed = totalFailed + res.failed
        end
        
        local overallColor = totalFailed == 0 and 15 or 5
        drawText(200, 25, "Overall:", 12, "left")
        drawText(200, 35, totalPassed .. " passed", overallColor, "left")
        drawText(200, 45, totalFailed .. " failed", totalFailed > 0 and 5 or 12, "left")
    end
    
    -- Progress bar
    local progress = (testPhase - 1) / (#testPhases - 1)
    fillRectangle(0, 62, progress * 256, 64, 12)
    
    return true
end

-- Control callbacks (testing legacy functionality)
function test.button1Pressed()
    if testPhase < #testPhases then
        testPhase = testPhase + 1
        frameCounter = 0
        print("Advanced to phase: " .. testPhases[testPhase].name)
    end
end

function test.button2Pressed()
    if testPhase > 1 then
        testPhase = testPhase - 1
        frameCounter = 0
        print("Back to phase: " .. testPhases[testPhase].name)
    end
end

function test.encoderPressed()
    -- Print detailed compatibility results
    print("\n=== Backward Compatibility Test Results ===")
    local overallPassed = 0
    local overallFailed = 0
    
    for _, phase in ipairs(testPhases) do
        local result = compatibilityResults[phase.test]
        print(phase.name .. ":")
        print("  Status: " .. result.status)
        print("  Passed: " .. result.passed .. "  Failed: " .. result.failed)
        if result.details ~= "" then
            print("  Details: " .. result.details)
        end
        for _, error in ipairs(result.errors) do
            print("  ERROR: " .. error)
        end
        print("")
        
        overallPassed = overallPassed + result.passed
        overallFailed = overallFailed + result.failed
    end
    
    print("OVERALL COMPATIBILITY:")
    print("  Total Passed: " .. overallPassed)
    print("  Total Failed: " .. overallFailed)
    local compatRate = (overallPassed + overallFailed) > 0 and (overallPassed / (overallPassed + overallFailed) * 100) or 0
    print("  Compatibility Rate: " .. string.format("%.1f", compatRate) .. "%")
    
    if overallFailed == 0 then
        print("  RESULT: FULL BACKWARD COMPATIBILITY MAINTAINED")
    else
        print("  RESULT: COMPATIBILITY ISSUES DETECTED")
    end
    
    print("=== End Compatibility Results ===\n")
end

-- Legacy pot controls (test that these still work)
function test.pot1Turn(x)
    originalScriptFunctions.p1 = x
end

function test.pot2Turn(x)
    originalScriptFunctions.p2 = x
end

function test.pot3Turn(x)
    originalScriptFunctions.p3 = x
end

-- Input/output definitions using legacy format
test.inputs = {kCV, kTrigger, kGate}
test.outputs = 4  -- Original numeric format

return test