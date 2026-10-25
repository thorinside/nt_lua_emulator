local store = require("modules.json_store")
local config = require("modules.config")
local ioState = require("modules.io_state")
local json = require("lib.dkjson")
local originalOpen, originalRename, originalRemove = io.open, os.rename, os.remove
local files, fault, closes, renames = {}, nil, 0, 0
io.open = function(path, mode)
    assert(mode == "wb", "save must only open the temporary file")
    assert(path:sub(-4) == ".tmp", "never truncate the destination")
    if fault == "open" then return nil, "permission denied" end
    files[path] = ""
    return {
        write = function(_, data)
            files[path] = data:sub(1, 5)
            if fault == "write" then return nil, "disk full" end
            if fault == "throw" then error("write failure") end
            files[path] = data; return true
        end,
        close = function()
            closes = closes + 1
            if fault == "close" then return nil, "flush failed" end
            return true
        end
    }
end
os.rename = function(from, to)
    renames = renames + 1
    if fault == "rename" then return nil, "rename failed" end
    files[to], files[from] = files[from], nil
    return true
end
os.remove = function(path) files[path] = nil; return true end
for _, mode in ipairs({"open", "write", "throw", "close", "rename"}) do
    fault, files["state.json"], closes, renames = mode, "old good state", 0, 0
    ioState.markMappingsChanged()
    local ok, err = ioState.saveIOState({scriptPath = "test.lua"}, true)
    assert(not ok and type(err) == "string")
    assert(files["state.json"] == "old good state", mode)
    assert(files["state.json.tmp"] == nil, "failed writes must clean up")
    assert(ioState.getMappingsChanged(), "failed save must remain dirty")
    assert(closes == (mode == "open" and 0 or 1), "always close a successfully opened file")
    assert(renames == (mode == "rename" and 1 or 0), "never rename an incomplete write")
end
fault = nil
love = {window = {getPosition = function() return 10, 20 end,
                 getMode = function() return 900, 700 end}}
assert(ioState.saveIOState({scriptPath = "test.lua"}, true))
assert(not ioState.getMappingsChanged())
local state = json.decode(files["state.json"])
assert(state.window.width == 900 and state.window.height == 700)
assert(state.window.x == 10 and state.window.y == 20)
local cycle = {}; cycle.self = cycle
local old = files["state.json"]
assert(not ioState.saveStateFile(cycle)); assert(files["state.json"] == old)
files["config.json"] = "old config"
fault = "close"
assert(not config.save({midi = {enabled = false}})); assert(files["config.json"] == "old config")
fault = nil
assert(config.save({midi = {enabled = false}}))
assert(json.decode(files["config.json"]).midi.enabled == false)
io.open, os.rename, os.remove = originalOpen, originalRename, originalRemove
-- Verify real filesystem replacement as well as injected failures.
local path = os.tmpname()
assert(store.save(path, {version = 1}))
assert(store.save(path, {version = 2}))
local f = assert(io.open(path, "rb")); local saved = json.decode(f:read("*a")); f:close()
assert(saved.version == 2)
os.remove(path)
print("Persistence failure/recovery tests passed")
