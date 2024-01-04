local M = {}

local types_ok, _ = pcall(require, 'agitate.types.error')
if not types_ok then
    return vim.api.nvim_err_writeln(require('agitate.const.error').import_error)
end

---Throws the given error, closing the current execution of agitate.nvim
---@param error AgitateError|table|string The error to throw
function M.throw(error)
    if type(error) == 'table' then
        for _, value in ipairs(error) do
            M.throw(value)
        end
    end
    vim.api.nvim_err_writeln('There was an error during execution of agitate.nvim:')
    if type(error) ~= "string" then
        return M.throw(M.unhandled('agitate.error.throw'))
    end
    vim.api.nvim_err_writeln(error)
end

---@param location string Where the error happens
---@return AgitateError Error
function M.unhandled(location)
    return {
        message = 'Unhandled error at `' .. location .. '`'
    }
end

return M
