local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

local config_ok, config_or_err = pcall(require, 'agitate.config')
if not config_ok then
  return agitate_error.throw(config_or_err)
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
