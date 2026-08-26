local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.config')
if not types_ok then
  agitate_error.throw(types_or_err)
  error(types_or_err, 0)
end

---@type Config
local defaults = {
  github_username = nil,
  github_access_token = nil,
  repo = {
    init = {
      show_status = false,
      first_commit_message = 'first commit',
      remote_protocol = 'https',
    },
  },
}

---@type Config
M.options = {}

---@param options Config|nil
function M.setup(options)
  M.options = vim.tbl_deep_extend('force', {}, defaults, options or {})

  local api_ok, api_or_err = pcall(require, 'agitate.api')
  if api_ok then
    api_or_err.setup()
  else
    agitate_error.throw(api_or_err)
  end
end

---@param options Config|nil
function M.extend(options)
  M.options = vim.tbl_deep_extend('force', {}, M.options or defaults, options or {})
end

M.setup()

return M
