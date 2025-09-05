-- performance_benchmark_test.lua
-- Performance benchmarking for API 1.10.0 features
-- Measures execution time, memory usage, and ensures no performance regressions

local test = {}

-- Benchmark state
local benchmarkIndex = 1
local frameCounter = 0
local benchmarkResults = {}
local isRunning = false
local iterations = 1000

-- Benchmark categories
local benchmarkCategories = {
    {name = "Algorithm Property Access", test = "algorithmProperty"},
    {name = "Algorithm Query Functions", test = "algorithmQueries"},
    {name = "Parameter Query Functions", test = "parameterQueries"},
    {name = "Display Mode Changes", test = "displayModes"},
    {name = "Text Rendering - No Alignment", test = "textNoAlignment"},
    {name = "Text Rendering - With Alignment", test = "textWithAlignment"},
    {name = "Mixed API Usage", test = "mixedUsage"},
    {name = "Memory Usage Analysis", test = "memoryAnalysis"}
}

function test.init()
    print("=== Performance Benchmark Test Suite ===")
    print("Measuring API 1.10.0 performance characteristics")
    
    benchmarkResults = {}
    benchmarkIndex = 1
    frameCounter = 0
    isRunning = false
    
    -- Initialize results
    for _, category in ipairs(benchmarkCategories) do
        benchmarkResults[category.test] = {
            name = category.name,
            executionTime = 0,
            memoryBefore = 0,
            memoryAfter = 0,
            iterationsPerSecond = 0,
            status = "pending",
            details = ""
        }
    end
    
    print("Initialized " .. #benchmarkCategories .. " performance benchmarks")
    print("Each benchmark will run " .. iterations .. " iterations")
end

function test.process(inputs, outputs)
    -- Process audio while running benchmarks to test real-world performance
    for i = 1, 4 do
        outputs[i] = math.sin(love.timer.getTime() * 440 * i) * 0.1
    end
end

-- Benchmark algorithm property access
local function benchmarkAlgorithmProperty()
    local result = benchmarkResults["algorithmProperty"]
    result.status = "running"
    
    -- Memory before
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    -- Benchmark
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        local index = self.algorithmIndex
        -- Do something with the value to prevent optimization
        if index and index >= 0 then
            local dummy = index + 1
        end
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    -- Memory after
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Algorithm Property Benchmark: " .. result.details)
end

-- Benchmark algorithm query functions
local function benchmarkAlgorithmQueries()
    local result = benchmarkResults["algorithmQueries"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        local count = getAlgorithmCount()
        if count and count > 0 then
            local name = getAlgorithmName(0)
            -- Use the name to prevent optimization
            if name then
                local len = string.len(name)
            end
        end
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Algorithm Queries Benchmark: " .. result.details)
end

-- Benchmark parameter query functions
local function benchmarkParameterQueries()
    local result = benchmarkResults["parameterQueries"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        local count = getParameterCount(0)
        if count and count > 0 then
            local name = getParameterName(0, 0)
            -- Use the name to prevent optimization
            if name then
                local len = string.len(name)
            end
        end
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Parameter Queries Benchmark: " .. result.details)
end

-- Benchmark display mode changes
local function benchmarkDisplayModes()
    local result = benchmarkResults["displayModes"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        local mode = i % 6
        local success = setDisplayMode(mode)
        -- Use the success value
        if success then
            local dummy = 1
        end
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    -- Reset to normal mode
    setDisplayMode(0)
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Display Mode Benchmark: " .. result.details)
end

-- Benchmark text rendering without alignment
local function benchmarkTextNoAlignment()
    local result = benchmarkResults["textNoAlignment"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        drawText(100, 20, "Benchmark Text " .. (i % 10), 12)
        drawTinyText(100, 30, "Tiny Benchmark " .. (i % 10), 8)
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Text No Alignment Benchmark: " .. result.details)
end

-- Benchmark text rendering with alignment
local function benchmarkTextWithAlignment()
    local result = benchmarkResults["textWithAlignment"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local alignments = {"left", "centre", "right"}
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        local alignment = alignments[(i % 3) + 1]
        drawText(100, 20, "Aligned Text " .. (i % 10), 12, alignment)
        drawTinyText(100, 30, "Tiny Aligned " .. (i % 10), 8, alignment)
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Text With Alignment Benchmark: " .. result.details)
end

-- Benchmark mixed API usage
local function benchmarkMixedUsage()
    local result = benchmarkResults["mixedUsage"]
    result.status = "running"
    
    collectgarbage("collect")
    result.memoryBefore = collectgarbage("count")
    
    local startTime = love.timer.getTime()
    
    for i = 1, iterations do
        -- Mix all API calls
        local algIndex = self.algorithmIndex
        local algCount = getAlgorithmCount()
        
        if algCount and algCount > 0 then
            local algName = getAlgorithmName(0)
            local paramCount = getParameterCount(0)
            
            if paramCount and paramCount > 0 then
                local paramName = getParameterName(0, 0)
            end
        end
        
        setDisplayMode(i % 6)
        drawText(50, 20, "Mixed " .. i, 10, i % 2 == 0 and "left" or "right")
        drawTinyText(150, 30, "API " .. i, 8, "centre")
    end
    
    local endTime = love.timer.getTime()
    result.executionTime = endTime - startTime
    
    -- Reset display mode
    setDisplayMode(0)
    
    collectgarbage("collect")
    result.memoryAfter = collectgarbage("count")
    
    result.iterationsPerSecond = result.executionTime > 0 and (iterations / result.executionTime) or 0
    result.details = string.format("%.3fms total, %.1fK ops/sec", 
        result.executionTime * 1000, result.iterationsPerSecond / 1000)
    result.status = "completed"
    
    print("Mixed API Usage Benchmark: " .. result.details)
end

-- Analyze memory usage patterns
local function benchmarkMemoryAnalysis()
    local result = benchmarkResults["memoryAnalysis"]
    result.status = "running"
    
    -- Run multiple cycles and measure memory growth
    collectgarbage("collect")
    local initialMemory = collectgarbage("count")
    result.memoryBefore = initialMemory
    
    local memorySnapshots = {}
    local cycles = 10
    
    for cycle = 1, cycles do
        for i = 1, iterations / cycles do
            -- Create temporary strings and objects
            local algCount = getAlgorithmCount()
            local testString = "Memory test cycle " .. cycle .. " iteration " .. i
            drawText(100, 20, testString, 12, "centre")
            
            if algCount and algCount > 0 then
                local algName = getAlgorithmName(0)
                local combinedString = testString .. " " .. (algName or "")
            end
        end
        
        -- Take memory snapshot
        collectgarbage("collect")
        table.insert(memorySnapshots, collectgarbage("count"))
    end
    
    result.memoryAfter = collectgarbage("count")
    
    -- Analyze memory growth
    local memoryGrowth = result.memoryAfter - result.memoryBefore
    local maxGrowthBetweenSnapshots = 0
    
    for i = 2, #memorySnapshots do
        local growth = memorySnapshots[i] - memorySnapshots[i-1]
        maxGrowthBetweenSnapshots = math.max(maxGrowthBetweenSnapshots, growth)
    end
    
    result.details = string.format("Growth: %.1fKB, Max cycle: %.1fKB, Snapshots: %d", 
        memoryGrowth, maxGrowthBetweenSnapshots, #memorySnapshots)
    result.status = "completed"
    
    print("Memory Analysis: " .. result.details)
    print("  Memory snapshots: " .. table.concat(memorySnapshots, ", "))
end

function test.render()
    -- Clear display
    fillRectangle(0, 0, 256, 64, 0)
    
    -- Auto-run benchmarks
    frameCounter = frameCounter + 1
    if frameCounter > 60 then -- 1 second delay between benchmarks
        frameCounter = 0
        if benchmarkIndex <= #benchmarkCategories and not isRunning then
            isRunning = true
            
            local currentCategory = benchmarkCategories[benchmarkIndex]
            print("Running benchmark: " .. currentCategory.name)
            
            -- Run the benchmark
            local benchmarkFunction = {
                algorithmProperty = benchmarkAlgorithmProperty,
                algorithmQueries = benchmarkAlgorithmQueries,
                parameterQueries = benchmarkParameterQueries,
                displayModes = benchmarkDisplayModes,
                textNoAlignment = benchmarkTextNoAlignment,
                textWithAlignment = benchmarkTextWithAlignment,
                mixedUsage = benchmarkMixedUsage,
                memoryAnalysis = benchmarkMemoryAnalysis
            }
            
            if benchmarkFunction[currentCategory.test] then
                benchmarkFunction[currentCategory.test]()
            end
            
            benchmarkIndex = benchmarkIndex + 1
            isRunning = false
        end
    end
    
    -- Display current status
    drawText(128, 5, "Performance Benchmark Suite", 15, "centre")
    
    if benchmarkIndex <= #benchmarkCategories then
        local currentCategory = benchmarkCategories[benchmarkIndex]
        drawText(128, 15, "Running: " .. currentCategory.name, 10, "centre")
        drawText(128, 25, "Benchmark " .. benchmarkIndex .. "/" .. #benchmarkCategories, 8, "centre")
    else
        drawText(128, 15, "All Benchmarks Complete", 12, "centre")
        
        -- Show summary
        local totalTime = 0
        local completedBenchmarks = 0
        
        for _, category in ipairs(benchmarkCategories) do
            local result = benchmarkResults[category.test]
            if result.status == "completed" then
                totalTime = totalTime + result.executionTime
                completedBenchmarks = completedBenchmarks + 1
            end
        end
        
        drawText(128, 25, "Total Time: " .. string.format("%.3f", totalTime * 1000) .. "ms", 10, "centre")
        drawText(128, 35, "Completed: " .. completedBenchmarks .. " benchmarks", 8, "centre")
        
        -- Show current benchmark details
        if benchmarkIndex > 1 then
            local lastBenchmark = benchmarkCategories[math.min(benchmarkIndex - 1, #benchmarkCategories)]
            local result = benchmarkResults[lastBenchmark.test]
            drawTinyText(10, 45, lastBenchmark.name .. ": " .. result.details, 6)
            
            local memoryChange = result.memoryAfter - result.memoryBefore
            if memoryChange ~= 0 then
                drawTinyText(10, 55, "Memory: " .. string.format("%.1f", memoryChange) .. "KB change", 6)
            end
        end
    end
    
    -- Progress bar
    local progress = math.min(benchmarkIndex - 1, #benchmarkCategories) / #benchmarkCategories
    fillRectangle(0, 62, progress * 256, 64, 15)
    
    -- Performance indicators
    if isRunning then
        drawText(250, 5, "●", 5, "right") -- Running indicator
    end
    
    return true
end

-- Control callbacks
function test.button1Pressed()
    -- Skip to next benchmark
    if benchmarkIndex <= #benchmarkCategories then
        benchmarkIndex = benchmarkIndex + 1
        frameCounter = 0
        isRunning = false
        print("Skipped to next benchmark")
    end
end

function test.button2Pressed()
    -- Restart benchmarks
    benchmarkIndex = 1
    frameCounter = 0
    isRunning = false
    
    -- Clear results
    for _, category in ipairs(benchmarkCategories) do
        benchmarkResults[category.test].status = "pending"
        benchmarkResults[category.test].executionTime = 0
    end
    
    print("Restarted benchmark suite")
end

function test.encoderPressed()
    -- Print detailed benchmark results
    print("\n=== Performance Benchmark Results ===")
    print("Each benchmark ran " .. iterations .. " iterations")
    print("")
    
    local totalTime = 0
    local worstPerformance = {name = "", time = 0}
    local bestPerformance = {name = "", time = math.huge}
    
    for _, category in ipairs(benchmarkCategories) do
        local result = benchmarkResults[category.test]
        if result.status == "completed" then
            print(category.name .. ":")
            print("  Execution Time: " .. string.format("%.3f", result.executionTime * 1000) .. "ms")
            print("  Iterations/sec: " .. string.format("%.0f", result.iterationsPerSecond))
            print("  Memory Before: " .. string.format("%.1f", result.memoryBefore) .. "KB")
            print("  Memory After: " .. string.format("%.1f", result.memoryAfter) .. "KB")
            print("  Memory Change: " .. string.format("%.1f", result.memoryAfter - result.memoryBefore) .. "KB")
            print("  Details: " .. result.details)
            print("")
            
            totalTime = totalTime + result.executionTime
            
            if result.executionTime > worstPerformance.time then
                worstPerformance = {name = category.name, time = result.executionTime}
            end
            
            if result.executionTime < bestPerformance.time then
                bestPerformance = {name = category.name, time = result.executionTime}
            end
        end
    end
    
    print("Summary:")
    print("  Total Execution Time: " .. string.format("%.3f", totalTime * 1000) .. "ms")
    print("  Best Performance: " .. bestPerformance.name .. " (" .. string.format("%.3f", bestPerformance.time * 1000) .. "ms)")
    print("  Worst Performance: " .. worstPerformance.name .. " (" .. string.format("%.3f", worstPerformance.time * 1000) .. "ms)")
    print("=== End Performance Results ===\n")
end

-- Input/output definitions for performance testing under load
test.inputs = {kCV, kTrigger, kGate, kCV}
test.outputs = {kCV, kCV, kGate, kTrigger}

return test