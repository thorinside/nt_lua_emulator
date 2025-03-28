-- script_manager.lua
-- Module for managing script execution, callbacks, and control interactions
local M = {} -- Module table
local script_utils = require("modules.script_utils")

-- Local state variables
local script = nil
local scriptPath = "test_script.lua" -- Default path
local scriptLastModified = 0
local reloadBlink = false
local lastReloadTime = 0
local enableAutoReload = true
local scriptMemoryTracking = false

-- Initialize the script manager
function M.init(deps)
    -- Store dependencies
    M.scriptLoader = deps.scriptLoader
    M.safeScriptCall = deps.safeScriptCall
    M.controls = deps.controls
    M.notifications = deps.notifications

    return M
end

-- Set the script path
function M.setScriptPath(path)
    scriptPath = path
    return scriptPath
end

-- Get the current script path
function M.getScriptPath() return scriptPath end

-- Get the current script object
function M.getScript() return script end

-- Set the current script object
function M.setScript(scriptObj)
    script = scriptObj
    return script
end

-- Get script reload state
function M.getReloadState()
    return {
        reloadBlink = reloadBlink,
        lastReloadTime = lastReloadTime,
        enableAutoReload = enableAutoReload
    }
end

-- Toggle auto reload
function M.toggleAutoReload()
    enableAutoReload = not enableAutoReload
    return enableAutoReload
end

-- Set auto reload state
function M.setAutoReload(enabled)
    enableAutoReload = enabled
    return enableAutoReload
end

-- Check if script has control callbacks
function M.hasControlCallbacks(scriptObj)
    if not scriptObj then return false end

    return scriptObj.button ~= nil or scriptObj.pot1Turn ~= nil or
               scriptObj.pot2Turn ~= nil or scriptObj.pot3Turn ~= nil or
               scriptObj.pot1Push ~= nil or scriptObj.pot2Push ~= nil or
               scriptObj.pot3Push ~= nil or scriptObj.pot1Release ~= nil or
               scriptObj.pot2Release ~= nil or scriptObj.pot3Release ~= nil or
               scriptObj.encoder1Turn ~= nil or scriptObj.encoder2Turn ~= nil or
               scriptObj.encoder1Push ~= nil or scriptObj.encoder2Push ~= nil or
               scriptObj.encoder1Release ~= nil or scriptObj.encoder2Release ~=
               nil or scriptObj.button1Push ~= nil or scriptObj.button2Push ~=
               nil or scriptObj.button3Push ~= nil or scriptObj.button4Push ~=
               nil or scriptObj.button1Release ~= nil or
               scriptObj.button2Release ~= nil or scriptObj.button3Release ~=
               nil or scriptObj.button4Release ~= nil
end

-- Set script control callbacks for the controls module
function M.setupControlCallbacks(scriptObj)
    if not scriptObj then return false end

    local controlCallbacks = {
        onButtonPress = function(buttonIndex)
            if scriptObj then
                local functionName = "button" .. buttonIndex .. "Push"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                elseif scriptObj.button then
                    M.safeScriptCall(scriptObj.button, scriptObj, buttonIndex,
                                     true)
                end
            end
        end,
        onButtonRelease = function(buttonIndex)
            if scriptObj then
                local functionName = "button" .. buttonIndex .. "Release"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                elseif scriptObj.button then
                    M.safeScriptCall(scriptObj.button, scriptObj, buttonIndex,
                                     false)
                end
            end
        end,
        onPotChange = function(potIndex, value)
            if scriptObj then
                local functionName = "pot" .. potIndex .. "Turn"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj, value)
                elseif scriptObj.pot then
                    M.safeScriptCall(scriptObj.pot, scriptObj, potIndex, value)
                end
            end
        end,
        onPotPress = function(potIndex)
            if scriptObj then
                local functionName = "pot" .. potIndex .. "Push"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                end
            end
        end,
        onPotRelease = function(potIndex)
            if scriptObj then
                local functionName = "pot" .. potIndex .. "Release"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                end
            end
        end,
        onEncoderChange = function(encoderIndex, delta)
            if scriptObj then
                local functionName = "encoder" .. encoderIndex .. "Turn"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj, delta)
                elseif scriptObj.encoder then
                    M.safeScriptCall(scriptObj.encoder, scriptObj, encoderIndex,
                                     delta)
                end
            end
        end,
        onEncoderPress = function(encoderIndex)
            if scriptObj then
                local functionName = "encoder" .. encoderIndex .. "Push"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                end
            end
        end,
        onEncoderRelease = function(encoderIndex)
            if scriptObj then
                local functionName = "encoder" .. encoderIndex .. "Release"
                if scriptObj[functionName] then
                    M.safeScriptCall(scriptObj[functionName], scriptObj)
                end
            end
        end
    }

    M.controls.setCallbacks(controlCallbacks)
    return true
end

-- Update the reload blink state based on current time
function M.updateReloadBlink(time)
    if reloadBlink and (time - lastReloadTime) > 1.0 then reloadBlink = false end
end

-- Check if the script file has been modified
function M.checkScriptModified(time)
    if not enableAutoReload then return false end

    local modified = M.scriptLoader.checkScriptModified(scriptPath)
    return modified
end

-- Handle script reloading
function M.reloadScript(createDefaultMappings, prevInputAssignments,
                        prevOutputAssignments)
    print("Script file changed, reloading...")

    local newScript, newScriptParameters =
        M.scriptLoader.loadScript(scriptPath, createDefaultMappings)

    if newScript then
        -- Update the script and parameters
        script = newScript

        -- Set up control callbacks
        M.setupControlCallbacks(script)

        -- Mark the reload state
        reloadBlink = true
        lastReloadTime = os.time()

        -- Return the new script and parameters
        return true, script, newScriptParameters
    else
        print("Error reloading script, continuing with previous version")
        return false, nil, nil
    end
end

-- Call the script's step function
function M.callScriptStep(dt, inputValues)
    if not script or not script.step then return nil end

    if scriptMemoryTracking then
        return script_utils.trackScriptStepMemory(script, dt, inputValues)
    else
        return M.safeScriptCall(script.step, script, dt, inputValues)
    end
end

-- Call the script's draw function
function M.callScriptDraw()
    if not script or not script.draw then return false end

    if scriptMemoryTracking then
        return script_utils.trackScriptDrawMemory(script)
    else
        return M.safeScriptCall(script.draw, script)
    end
end

-- Get script I/O counts
function M.getScriptIOCounts()
    if not script then return 0, 0 end

    local inputCount = 0
    local outputCount = 0

    if type(script.inputs) == "number" then
        inputCount = script.inputs
    elseif type(script.inputs) == "table" then
        inputCount = #script.inputs
    end

    if type(script.outputs) == "number" then
        outputCount = script.outputs
    elseif type(script.outputs) == "table" then
        outputCount = #script.outputs
    end

    return inputCount, outputCount
end

-- Toggle script memory profiling
function M.toggleScriptMemoryTracking()
    scriptMemoryTracking = not scriptMemoryTracking
    
    if scriptMemoryTracking then
        script_utils.startScriptMemoryTracking()
        print("Script memory profiling enabled - tracking step(), draw(), gate(), and trigger() functions")
    else
        -- Get report before stopping
        local report = script_utils.getScriptMemoryReport()
        script_utils.printScriptMemoryReport()
        script_utils.stopScriptMemoryTracking()
        return report
    end
    
    return scriptMemoryTracking
end

-- Check if script memory tracking is enabled
function M.isScriptMemoryTrackingEnabled()
    return scriptMemoryTracking
end

-- Call the script's gate function with memory tracking
function M.callScriptGate(params)
    if not script or not script.gate then return nil end

    if scriptMemoryTracking then
        return script_utils.trackScriptGateMemory(script, params)
    else
        return M.safeScriptCall(script.gate, script, params)
    end
end

-- Call the script's trigger function with memory tracking
function M.callScriptTrigger(params)
    if not script or not script.trigger then return nil end

    if scriptMemoryTracking then
        return script_utils.trackScriptTriggerMemory(script, params)
    else
        return M.safeScriptCall(script.trigger, script, params)
    end
end

return M
