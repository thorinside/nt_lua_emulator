-- Single-writer JSON persistence. Replace only after a complete write and close.
-- A failed rename (including platforms that cannot replace an open target) leaves
-- the old file intact; never remove the destination as a fallback.
local json = require("lib.dkjson")
local M = {}
function M.save(path, value)
    local ok, encoded = pcall(json.encode, value, {indent = true})
    if not ok or type(encoded) ~= "string" then
        return false, "JSON encoding failed: " .. tostring(encoded)
    end
    local temporary = path .. ".tmp"
    local file, err = io.open(temporary, "wb")
    if not file then return false, tostring(err) end
    local written, writeResult, writeError = pcall(file.write, file, encoded)
    local closed, closeResult, closeError = pcall(file.close, file)
    if not written or not writeResult or not closed or not closeResult then
        os.remove(temporary)
        return false, tostring(not written and writeResult or writeError or
                              (not closed and closeResult or closeError) or "Write failed")
    end
    local renamed, renameError = os.rename(temporary, path)
    if not renamed then
        os.remove(temporary)
        return false, tostring(renameError)
    end
    return true
end
return M
