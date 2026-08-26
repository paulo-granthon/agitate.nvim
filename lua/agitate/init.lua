local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local config_ok, config_or_err = pcall(require, 'agitate.config')
if not config_ok then
  agitate_error.throw(config_or_err)
  error(config_or_err, 0)
end

local config = config_or_err

---@param opts Config|nil
function M.load(opts)
  if opts then
    config.extend(opts)
  end
end

M.setup = config.setup

return M
