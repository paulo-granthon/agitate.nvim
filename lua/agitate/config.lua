local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
    return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.config')
if not types_ok then return error.throw(types_or_err) end

---@type Config
local defaults = {
    github_username = nil,
    repo = {
        show_status_on_init = false,
    },
}

---@type Config
M.options = {}

---@param options Config|nil
function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})

    local api_ok, api_or_err = pcall(require, 'agitate.api')
    if api_ok then api_or_err.setup()
    else error.throw(api_or_err) end
end

---@param options Config|nil
function M.extend(options)
    M.options = vim.tbl_deep_extend("force", {}, M.options or defaults, options or {})
end

M.setup()

return M
