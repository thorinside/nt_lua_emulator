local scriptManager = require("modules.script_manager")

local callbacks
local errors = {}
local controls = {
    setCallbacks = function(value)
        callbacks = value
    end
}
local notifications = {
    showErrorNotification = function(message)
        errors[#errors + 1] = message
    end
}
local function safeScriptCall(callback, self, ...)
    return callback(self, ...)
end

scriptManager.init({
    scriptLoader = {},
    safeScriptCall = safeScriptCall,
    controls = controls,
    notifications = notifications
})

local uiValue
local uiScript = {
    isUiScript = true,
    pot3Turn = function(value)
        uiValue = value
    end
}
scriptManager.setupControlCallbacks(uiScript)
callbacks.onPotChange(3, 0.75)
if uiValue ~= 0.75 then
    error("UI script callback received an injected self argument")
end

local algorithmSelf
local algorithmValue
local algorithmScript = {
    pot3Turn = function(self, value)
        algorithmSelf = self
        algorithmValue = value
    end
}
scriptManager.setupControlCallbacks(algorithmScript)
callbacks.onPotChange(3, 0.25)
if algorithmSelf ~= algorithmScript or algorithmValue ~= 0.25 then
    error("algorithm callback lost its self argument")
end

local standardLineCount = 0
_G.drawStandardParameterLine = function()
    standardLineCount = standardLineCount + 1
end
algorithmScript.draw = function() return false end
scriptManager.setScript(algorithmScript)
scriptManager.callScriptDraw()
if standardLineCount ~= 1 then
    error("algorithm draw returning false must include the standard parameter line")
end

uiScript.draw = function() end
scriptManager.setScript(uiScript)
scriptManager.callScriptDraw()
if standardLineCount ~= 1 then
    error("UI scripts must control their own complete display")
end

if #errors ~= 0 then error(errors[1]) end

print("UI script callback tests passed")
