local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
    return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

local config_ok, config_or_err = pcall(require, 'agitate.config')
if not config_ok then return error.throw(config_or_err) end

local config = config_or_err

---@param opts Config|nil
function M.load(opts)
    if opts then
        config.extend(opts)
    end
end

M.setup = config.setup

return M
