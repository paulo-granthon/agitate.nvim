local M = {}

require('types.error')

---@param location string Where the error happens
---@return AgitateError Error 
function M.unhandled(location)
    return {
        message = 'Unhandled error at `' .. location .. '`'
    }
end

return M
