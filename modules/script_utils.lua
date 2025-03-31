-- script_utils.lua
-- Utility functions for script authors to profile and optimize memory usage
local script_utils = {}
local debug_utils = require("modules.debug_utils")

-- Memory tracking state
local scriptMemoryTracking = {
    enabled = false,
    -- Track GC counts globally
    gcCountBefore = 0,
    gcCountAfter = 0,
    totalGcCount = 0,
    -- Collect memory stats for step
    stepMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0, -- Track allocations
        gcTriggered = 0 -- Track GC runs
    },
    -- Collect memory stats for draw
    drawMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0, -- Track allocations
        gcTriggered = 0 -- Track GC runs
    },
    -- Collect memory stats for gate
    gateMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0, -- Track allocations
        gcTriggered = 0 -- Track GC runs
    },
    -- Collect memory stats for trigger
    triggerMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0, -- Track allocations
        gcTriggered = 0 -- Track GC runs
    }
}

-- Start memory tracking for scripts
function script_utils.startScriptMemoryTracking()
    scriptMemoryTracking.enabled = true
    collectgarbage("collect") -- Force a full collection before starting

    -- Get current GC count baseline
    scriptMemoryTracking.gcCountBefore = collectgarbage("count")
    scriptMemoryTracking.totalGcCount = 0

    -- Reset tracking stats
    scriptMemoryTracking.stepMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0,
        gcTriggered = 0
    }

    scriptMemoryTracking.drawMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0,
        gcTriggered = 0
    }

    scriptMemoryTracking.gateMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0,
        gcTriggered = 0
    }

    scriptMemoryTracking.triggerMemory = {
        totalCalls = 0,
        totalMemoryBefore = 0,
        totalMemoryAfter = 0,
        totalImpact = 0,
        peakImpact = 0,
        lastImpact = 0,
        allocations = 0,
        gcTriggered = 0
    }

    debug_utils.debugLog("Script memory tracking started")
    return true
end

-- Stop memory tracking for scripts
function script_utils.stopScriptMemoryTracking()
    scriptMemoryTracking.enabled = false
    debug_utils.debugLog("Script memory tracking stopped")
    return script_utils.getScriptMemoryReport()
end

-- Get current memory allocation info
local function getMemoryStats()
    local stats = {}
    stats.memoryUsage = collectgarbage("count")
    -- Store GC count if possible
    stats.gcCount = collectgarbage("count") -- We'll use this to detect GC runs
    return stats
end

-- Track memory usage for script's step function
function script_utils.trackScriptStepMemory(scriptObj, dt, inputs)
    if not scriptMemoryTracking.enabled then
        return scriptObj.step(scriptObj, dt, inputs)
    end

    local statsBefore = getMemoryStats()
    local memoryBefore = statsBefore.memoryUsage
    local gcCountBefore = statsBefore.gcCount

    scriptMemoryTracking.stepMemory.totalCalls =
        scriptMemoryTracking.stepMemory.totalCalls + 1
    scriptMemoryTracking.stepMemory.totalMemoryBefore =
        scriptMemoryTracking.stepMemory.totalMemoryBefore + memoryBefore

    -- Call the script's step function and capture its result, including nil returns
    local result = scriptObj.step(scriptObj, dt, inputs)

    local statsAfter = getMemoryStats()
    local memoryAfter = statsAfter.memoryUsage
    local gcCountAfter = statsAfter.gcCount

    scriptMemoryTracking.stepMemory.totalMemoryAfter =
        scriptMemoryTracking.stepMemory.totalMemoryAfter + memoryAfter

    local memoryImpact = memoryAfter - memoryBefore
    scriptMemoryTracking.stepMemory.totalImpact =
        scriptMemoryTracking.stepMemory.totalImpact + memoryImpact
    scriptMemoryTracking.stepMemory.lastImpact = memoryImpact

    -- Track allocations - we estimate this based on positive memory impact
    if memoryImpact > 0 then
        scriptMemoryTracking.stepMemory.allocations =
            scriptMemoryTracking.stepMemory.allocations + 1
    end

    -- If memory decreased or stayed same, might be due to GC
    if memoryAfter < memoryBefore then
        scriptMemoryTracking.stepMemory.gcTriggered =
            scriptMemoryTracking.stepMemory.gcTriggered + 1
    end

    if memoryImpact > scriptMemoryTracking.stepMemory.peakImpact then
        scriptMemoryTracking.stepMemory.peakImpact = memoryImpact
    end

    if memoryImpact > 1 then
        debug_utils.debugLog(string.format(
                                 "Script step(): Memory impact %.2f KB",
                                 memoryImpact))
    end

    -- Return the result as is, which could be nil, table, or any other Lua value
    return result
end

-- Track memory usage for script's draw function
function script_utils.trackScriptDrawMemory(scriptObj)
    if not scriptMemoryTracking.enabled then return scriptObj.draw(scriptObj) end

    local statsBefore = getMemoryStats()
    local memoryBefore = statsBefore.memoryUsage
    local gcCountBefore = statsBefore.gcCount

    scriptMemoryTracking.drawMemory.totalCalls =
        scriptMemoryTracking.drawMemory.totalCalls + 1
    scriptMemoryTracking.drawMemory.totalMemoryBefore =
        scriptMemoryTracking.drawMemory.totalMemoryBefore + memoryBefore

    -- Call the script's draw function
    scriptObj.draw(scriptObj)

    local statsAfter = getMemoryStats()
    local memoryAfter = statsAfter.memoryUsage
    local gcCountAfter = statsAfter.gcCount

    scriptMemoryTracking.drawMemory.totalMemoryAfter =
        scriptMemoryTracking.drawMemory.totalMemoryAfter + memoryAfter

    local memoryImpact = memoryAfter - memoryBefore
    scriptMemoryTracking.drawMemory.totalImpact =
        scriptMemoryTracking.drawMemory.totalImpact + memoryImpact
    scriptMemoryTracking.drawMemory.lastImpact = memoryImpact

    -- Track allocations - we estimate this based on positive memory impact
    if memoryImpact > 0 then
        scriptMemoryTracking.drawMemory.allocations =
            scriptMemoryTracking.drawMemory.allocations + 1
    end

    -- If memory decreased or stayed same, might be due to GC
    if memoryAfter < memoryBefore then
        scriptMemoryTracking.drawMemory.gcTriggered =
            scriptMemoryTracking.drawMemory.gcTriggered + 1
    end

    if memoryImpact > scriptMemoryTracking.drawMemory.peakImpact then
        scriptMemoryTracking.drawMemory.peakImpact = memoryImpact
    end

    if memoryImpact > 1 then
        debug_utils.debugLog(string.format(
                                 "Script draw(): Memory impact %.2f KB",
                                 memoryImpact))
    end
end

-- Track memory usage for script's gate function when available
function script_utils.trackScriptGateMemory(scriptObj, params)
    if not scriptMemoryTracking.enabled or not scriptObj.gate then return nil end

    local statsBefore = getMemoryStats()
    local memoryBefore = statsBefore.memoryUsage
    local gcCountBefore = statsBefore.gcCount

    scriptMemoryTracking.gateMemory.totalCalls =
        scriptMemoryTracking.gateMemory.totalCalls + 1
    scriptMemoryTracking.gateMemory.totalMemoryBefore =
        scriptMemoryTracking.gateMemory.totalMemoryBefore + memoryBefore

    -- Call the script's gate function with proper parameters
    local result
    if type(params) == "table" and params.input ~= nil then
        result = scriptObj.gate(scriptObj, params.input, params.rising)
    else
        -- Fallback to directly passing params if it's not a table
        result = scriptObj.gate(scriptObj, params)
    end

    local statsAfter = getMemoryStats()
    local memoryAfter = statsAfter.memoryUsage
    local gcCountAfter = statsAfter.gcCount

    scriptMemoryTracking.gateMemory.totalMemoryAfter =
        scriptMemoryTracking.gateMemory.totalMemoryAfter + memoryAfter

    local memoryImpact = memoryAfter - memoryBefore
    scriptMemoryTracking.gateMemory.totalImpact =
        scriptMemoryTracking.gateMemory.totalImpact + memoryImpact
    scriptMemoryTracking.gateMemory.lastImpact = memoryImpact

    -- Track allocations - we estimate this based on positive memory impact
    if memoryImpact > 0 then
        scriptMemoryTracking.gateMemory.allocations =
            scriptMemoryTracking.gateMemory.allocations + 1
    end

    -- If memory decreased or stayed same, might be due to GC
    if memoryAfter < memoryBefore then
        scriptMemoryTracking.gateMemory.gcTriggered =
            scriptMemoryTracking.gateMemory.gcTriggered + 1
    end

    if memoryImpact > scriptMemoryTracking.gateMemory.peakImpact then
        scriptMemoryTracking.gateMemory.peakImpact = memoryImpact
    end

    if memoryImpact > 1 then
        debug_utils.debugLog(string.format(
                                 "Script gate(): Memory impact %.2f KB",
                                 memoryImpact))
    end

    return result
end

-- Track memory usage for script's trigger function when available
function script_utils.trackScriptTriggerMemory(scriptObj, params)
    if not scriptMemoryTracking.enabled or not scriptObj.trigger then
        return nil
    end

    local statsBefore = getMemoryStats()
    local memoryBefore = statsBefore.memoryUsage
    local gcCountBefore = statsBefore.gcCount

    scriptMemoryTracking.triggerMemory.totalCalls =
        scriptMemoryTracking.triggerMemory.totalCalls + 1
    scriptMemoryTracking.triggerMemory.totalMemoryBefore =
        scriptMemoryTracking.triggerMemory.totalMemoryBefore + memoryBefore

    -- Call the script's trigger function with the input parameter
    local result
    if type(params) == "table" and params.input ~= nil then
        result = scriptObj.trigger(scriptObj, params.input)
    else
        -- Fallback to directly passing params if it's not a table with input
        result = scriptObj.trigger(scriptObj, params)
    end

    local statsAfter = getMemoryStats()
    local memoryAfter = statsAfter.memoryUsage
    local gcCountAfter = statsAfter.gcCount

    scriptMemoryTracking.triggerMemory.totalMemoryAfter =
        scriptMemoryTracking.triggerMemory.totalMemoryAfter + memoryAfter

    local memoryImpact = memoryAfter - memoryBefore
    scriptMemoryTracking.triggerMemory.totalImpact =
        scriptMemoryTracking.triggerMemory.totalImpact + memoryImpact
    scriptMemoryTracking.triggerMemory.lastImpact = memoryImpact

    -- Track allocations - we estimate this based on positive memory impact
    if memoryImpact > 0 then
        scriptMemoryTracking.triggerMemory.allocations =
            scriptMemoryTracking.triggerMemory.allocations + 1
    end

    -- If memory decreased or stayed same, might be due to GC
    if memoryAfter < memoryBefore then
        scriptMemoryTracking.triggerMemory.gcTriggered =
            scriptMemoryTracking.triggerMemory.gcTriggered + 1
    end

    if memoryImpact > scriptMemoryTracking.triggerMemory.peakImpact then
        scriptMemoryTracking.triggerMemory.peakImpact = memoryImpact
    end

    if memoryImpact > 1 then
        debug_utils.debugLog(string.format(
                                 "Script trigger(): Memory impact %.2f KB",
                                 memoryImpact))
    end

    return result
end

-- Get a report on script memory usage
function script_utils.getScriptMemoryReport()
    local report = {
        step = {
            calls = scriptMemoryTracking.stepMemory.totalCalls,
            avgImpact = 0,
            totalImpact = scriptMemoryTracking.stepMemory.totalImpact,
            peakImpact = scriptMemoryTracking.stepMemory.peakImpact,
            lastImpact = scriptMemoryTracking.stepMemory.lastImpact,
            allocations = scriptMemoryTracking.stepMemory.allocations,
            gcTriggered = scriptMemoryTracking.stepMemory.gcTriggered
        },
        draw = {
            calls = scriptMemoryTracking.drawMemory.totalCalls,
            avgImpact = 0,
            totalImpact = scriptMemoryTracking.drawMemory.totalImpact,
            peakImpact = scriptMemoryTracking.drawMemory.peakImpact,
            lastImpact = scriptMemoryTracking.drawMemory.lastImpact,
            allocations = scriptMemoryTracking.drawMemory.allocations,
            gcTriggered = scriptMemoryTracking.drawMemory.gcTriggered
        },
        gate = {
            calls = scriptMemoryTracking.gateMemory.totalCalls,
            avgImpact = 0,
            totalImpact = scriptMemoryTracking.gateMemory.totalImpact,
            peakImpact = scriptMemoryTracking.gateMemory.peakImpact,
            lastImpact = scriptMemoryTracking.gateMemory.lastImpact,
            allocations = scriptMemoryTracking.gateMemory.allocations,
            gcTriggered = scriptMemoryTracking.gateMemory.gcTriggered
        },
        trigger = {
            calls = scriptMemoryTracking.triggerMemory.totalCalls,
            avgImpact = 0,
            totalImpact = scriptMemoryTracking.triggerMemory.totalImpact,
            peakImpact = scriptMemoryTracking.triggerMemory.peakImpact,
            lastImpact = scriptMemoryTracking.triggerMemory.lastImpact,
            allocations = scriptMemoryTracking.triggerMemory.allocations,
            gcTriggered = scriptMemoryTracking.triggerMemory.gcTriggered
        }
    }

    -- Calculate averages
    if report.step.calls > 0 then
        report.step.avgImpact = report.step.totalImpact / report.step.calls
    end

    if report.draw.calls > 0 then
        report.draw.avgImpact = report.draw.totalImpact / report.draw.calls
    end

    if report.gate.calls > 0 then
        report.gate.avgImpact = report.gate.totalImpact / report.gate.calls
    end

    if report.trigger.calls > 0 then
        report.trigger.avgImpact = report.trigger.totalImpact /
                                       report.trigger.calls
    end

    return report
end

-- Print a report on script memory usage
function script_utils.printScriptMemoryReport()
    local report = script_utils.getScriptMemoryReport()

    print("\n=== SCRIPT MEMORY USAGE REPORT ===")
    print(string.format(
              "step():    %d calls, %.2f KB total (%.2f KB avg, %.2f KB peak)",
              report.step.calls, report.step.totalImpact, report.step.avgImpact,
              report.step.peakImpact))
    print(string.format("          Allocations: %d, GC triggered: %d",
                        report.step.allocations, report.step.gcTriggered))

    print(string.format(
              "draw():    %d calls, %.2f KB total (%.2f KB avg, %.2f KB peak)",
              report.draw.calls, report.draw.totalImpact, report.draw.avgImpact,
              report.draw.peakImpact))
    print(string.format("          Allocations: %d, GC triggered: %d",
                        report.draw.allocations, report.draw.gcTriggered))

    if report.gate.calls > 0 then
        print(string.format(
                  "gate():    %d calls, %.2f KB total (%.2f KB avg, %.2f KB peak)",
                  report.gate.calls, report.gate.totalImpact,
                  report.gate.avgImpact, report.gate.peakImpact))
        print(string.format("          Allocations: %d, GC triggered: %d",
                            report.gate.allocations, report.gate.gcTriggered))
    end

    if report.trigger.calls > 0 then
        print(string.format(
                  "trigger(): %d calls, %.2f KB total (%.2f KB avg, %.2f KB peak)",
                  report.trigger.calls, report.trigger.totalImpact,
                  report.trigger.avgImpact, report.trigger.peakImpact))
        print(string.format("          Allocations: %d, GC triggered: %d",
                            report.trigger.allocations,
                            report.trigger.gcTriggered))
    end

    -- Calculate total memory impact
    local totalImpact = report.step.totalImpact + report.draw.totalImpact +
                            report.gate.totalImpact + report.trigger.totalImpact

    -- Calculate total calls and allocations
    local totalCalls =
        report.step.calls + report.draw.calls + report.gate.calls +
            report.trigger.calls
    local totalAllocations = report.step.allocations + report.draw.allocations +
                                 report.gate.allocations +
                                 report.trigger.allocations
    local totalGC = report.step.gcTriggered + report.draw.gcTriggered +
                        report.gate.gcTriggered + report.trigger.gcTriggered

    print(string.format("\nTotal memory impact: %.2f KB over %d function calls",
                        totalImpact, totalCalls))
    print(string.format("Total allocations: %d, Total GC runs: %d",
                        totalAllocations, totalGC))

    -- Add memory optimization recommendations
    print("\nRecommendations to minimize garbage collection:")
    print("1. Reuse tables instead of creating new ones each frame")
    print("2. Avoid string operations in step() and draw()")
    print("3. Minimize table creation in performance-critical callbacks")
    print("4. Pre-allocate tables with known sizes")
    print("5. Cache frequently used values")

    print("===================================\n")

    return report
end

return script_utils
