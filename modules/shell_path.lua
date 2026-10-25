-- POSIX shell arguments must not interpret quotes, substitutions, or options.
local M = {}
function M.quote(path)
    assert(type(path) == "string" and not path:find("\0", 1, true), "Invalid path")
    if path:sub(1, 1) == "-" then path = "./" .. path end
    return "'" .. path:gsub("'", "'\\''") .. "'"
end
return M
