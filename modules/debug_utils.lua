local emulator = nil

-- Get UI State for debug checking
local uiState = require("modules.ui_state")

-- Try to load emulator module for debug mode access
local function loadEmulator()
    if not emulator then pcall(function() emulator = require("emulator") end) end
end

-- Check if debug mode is enabled
local function isDebugMode()
    loadEmulator()
    if emulator and emulator.isDebugMode then return emulator.isDebugMode() end
    return false
end

-- Debug log function that only prints if debug mode is enabled
local function debugLog(...) if isDebugMode() then print("[DEBUG]", ...) end end

local debug_utils = {}
local debugFile = nil
local lastMemory = 0
local gcStats = {}
local functionCallCounts = {}

-- Log a debug message
local function mainDebugLog(...) -- Accept variable arguments
    -- Check uiState directly
    if uiState and uiState.isDebugMode and uiState.isDebugMode() then
        local timeStr = os.date("%Y-%m-%d %H:%M:%S")
        -- Concatenate all arguments into a single string
        local messageContent = table.concat({...}, " ")
        local logMessage = timeStr .. " - " .. messageContent
        print(logMessage)
        if debugFile then
            debugFile:write(logMessage .. "\n")
            debugFile:flush()
        end
    end
end

-- Initialize memory profiling
function debug_utils.initMemoryProfiling()
    collectgarbage("collect") -- Force a full garbage collection
    lastMemory = collectgarbage("count")
    debug_utils.debugLog("Memory profiling initialized. Current memory: " ..
                             lastMemory .. " KB")

    -- Reset statistics
    gcStats = {
        collections = 0,
        totalMemoryFreed = 0,
        peakMemory = lastMemory,
        memorySnapshots = {}
    }

    functionCallCounts = {}

    -- Take initial snapshot
    debug_utils.takeMemorySnapshot("Initial")

    return lastMemory
end

-- Take a memory snapshot with a label
function debug_utils.takeMemorySnapshot(label)
    local currentMemory = collectgarbage("count")
    local memoryDiff = currentMemory - lastMemory
    local snapshot = {
        label = label or "Snapshot " .. (#gcStats.memorySnapshots + 1),
        timestamp = os.time(),
        memory = currentMemory,
        diff = memoryDiff
    }

    table.insert(gcStats.memorySnapshots, snapshot)

    if currentMemory > gcStats.peakMemory then
        gcStats.peakMemory = currentMemory
    end

    if debugEnabled then
        local diffText = memoryDiff > 0 and "+" .. memoryDiff or
                             tostring(memoryDiff)
        debug_utils.debugLog("Memory " .. snapshot.label .. ": " ..
                                 currentMemory .. " KB (" .. diffText .. " KB)")
    end

    lastMemory = currentMemory
    return currentMemory, memoryDiff
end

-- Track a function call's memory impact
function debug_utils.trackFunctionMemory(funcName, func, ...)
    if not functionCallCounts[funcName] then
        functionCallCounts[funcName] = {
            calls = 0,
            totalMemoryBefore = 0,
            totalMemoryAfter = 0,
            totalMemoryImpact = 0
        }
    end

    local stats = functionCallCounts[funcName]
    stats.calls = stats.calls + 1

    local memoryBefore = collectgarbage("count")
    stats.totalMemoryBefore = stats.totalMemoryBefore + memoryBefore

    -- Call the function with the provided arguments
    local results = {func(...)}

    local memoryAfter = collectgarbage("count")
    stats.totalMemoryAfter = stats.totalMemoryAfter + memoryAfter

    local memoryImpact = memoryAfter - memoryBefore
    stats.totalMemoryImpact = stats.totalMemoryImpact + memoryImpact

    if debugEnabled and memoryImpact > 1 then
        debug_utils.debugLog(string.format("Function %s: Memory impact %.2f KB",
                                           funcName, memoryImpact))
    end

    return table.unpack(results)
end

-- Create a wrapper that tracks memory usage for a function
function debug_utils.createMemoryTrackingWrapper(funcName, func)
    return function(...)
        return debug_utils.trackFunctionMemory(funcName, func, ...)
    end
end

-- Monitor garbage collection in update loop
function debug_utils.monitorGC()
    local currentMemory = collectgarbage("count")
    if currentMemory < lastMemory then
        -- Garbage collection likely occurred
        local memoryFreed = lastMemory - currentMemory
        gcStats.collections = gcStats.collections + 1
        gcStats.totalMemoryFreed = gcStats.totalMemoryFreed + memoryFreed

        if debugEnabled then
            debug_utils.debugLog(string.format(
                                     "GC occurred: freed %.2f KB (collection #%d)",
                                     memoryFreed, gcStats.collections))
        end
    end

    lastMemory = currentMemory
    return currentMemory
end

-- Get memory profiling report
function debug_utils.getMemoryReport()
    local report = {
        currentMemory = collectgarbage("count"),
        peakMemory = gcStats.peakMemory,
        collections = gcStats.collections,
        totalMemoryFreed = gcStats.totalMemoryFreed,
        functionStats = {}
    }

    -- Sort functions by memory impact
    for funcName, stats in pairs(functionCallCounts) do
        local avgImpact = stats.calls > 0 and
                              (stats.totalMemoryImpact / stats.calls) or 0
        table.insert(report.functionStats, {
            name = funcName,
            calls = stats.calls,
            totalImpact = stats.totalMemoryImpact,
            avgImpact = avgImpact
        })
    end

    table.sort(report.functionStats,
               function(a, b) return a.totalImpact > b.totalImpact end)

    return report
end

-- Print memory report to console/log
function debug_utils.printMemoryReport()
    local report = debug_utils.getMemoryReport()

    debug_utils.debugLog("=== MEMORY PROFILING REPORT ===")
    debug_utils.debugLog(string.format("Current memory: %.2f KB",
                                       report.currentMemory))
    debug_utils.debugLog(
        string.format("Peak memory: %.2f KB", report.peakMemory))
    debug_utils.debugLog(string.format(
                             "GC collections: %d (freed %.2f KB total)",
                             report.collections, report.totalMemoryFreed))

    debug_utils.debugLog("\nTop memory-intensive functions:")
    for i, funcStats in ipairs(report.functionStats) do
        if i <= 10 then -- Show top 10
            debug_utils.debugLog(string.format(
                                     "%d. %s: %.2f KB total (%.2f KB avg, %d calls)",
                                     i, funcStats.name, funcStats.totalImpact,
                                     funcStats.avgImpact, funcStats.calls))
        end
    end

    debug_utils.debugLog("===============================")

    return report
end

-- Control garbage collection behavior
function debug_utils.setGCMode(mode, param)
    mode = mode or "setstepmul"
    param = param or 200 -- Default is fairly aggressive

    if mode == "setstepmul" then
        -- Controls how aggressive GC is (higher = more aggressive)
        -- Default is 200 (recommended range 100-400)
        collectgarbage(mode, param)
        debug_utils.debugLog("Set GC step multiplier to " .. param)
    elseif mode == "setpause" then
        -- Controls how much memory growth triggers GC (higher = less frequent)
        -- Default is 100 (as a percentage of current use)
        collectgarbage(mode, param)
        debug_utils.debugLog("Set GC pause to " .. param .. "%")
    else
        debug_utils.debugLog("Unknown GC mode: " .. mode)
    end
end

-- Assign the modified function back to the module export
debug_utils.debugLog = mainDebugLog

return debug_utils
