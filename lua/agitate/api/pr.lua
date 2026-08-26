local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

---Registers one pull request command, deferring the `core.pr` require until it runs.
---@param name string The command name
---@param method string The `core.pr` function to call
---@param desc string The command description
local function command(name, method, desc)
  vim.api.nvim_create_user_command(name, function(opts)
    local pr_ok, pr_or_err = pcall(require, 'agitate.core.pr')
    if not pr_ok then
      return agitate_error.throw(pr_or_err)
    end

    pr_or_err[method](opts.fargs)
  end, {
    nargs = '*',
    desc = desc,
  })
end

function M.setup()
  command('AgitatePrCreate', 'Create', 'Open a new pull request')
  command('AgitatePrList', 'List', 'List the pull requests of a repository')
  command('AgitatePrView', 'View', 'View a single pull request and its comments')
  command('AgitatePrComment', 'Comment', 'Comment on a pull request')
  command('AgitatePrMerge', 'Merge', 'Merge a pull request')
end

return M
