local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

---Registers one issue command, deferring the `core.issue` require until it runs.
---@param name string The command name
---@param method string The `core.issue` function to call
---@param desc string The command description
local function command(name, method, desc)
  vim.api.nvim_create_user_command(name, function(opts)
    local issue_ok, issue_or_err = pcall(require, 'agitate.core.issue')
    if not issue_ok then
      return agitate_error.throw(issue_or_err)
    end

    issue_or_err[method](opts.fargs)
  end, {
    nargs = '*',
    desc = desc,
  })
end

function M.setup()
  command('AgitateIssueCreate', 'Create', 'Open a new issue')
  command('AgitateIssueList', 'List', 'List the issues of a repository')
  command('AgitateIssueView', 'View', 'View a single issue and its comments')
  command('AgitateIssueComment', 'Comment', 'Comment on an issue')
  command('AgitateIssueClose', 'Close', 'Close an issue')
  command('AgitateIssueReopen', 'Reopen', 'Reopen a closed issue')
end

return M
