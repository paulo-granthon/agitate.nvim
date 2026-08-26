local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

function M.setup()
  local branch_ok, branch_or_err = pcall(require, 'agitate.api.branch')
  if branch_ok then
    branch_or_err.setup()
  else
    agitate_error.throw(branch_or_err)
  end

  local repo_ok, repo_or_err = pcall(require, 'agitate.api.repo')
  if repo_ok then
    repo_or_err.setup()
  else
    agitate_error.throw(repo_or_err)
  end

  local issue_ok, issue_or_err = pcall(require, 'agitate.api.issue')
  if issue_ok then
    issue_or_err.setup()
  else
    agitate_error.throw(issue_or_err)
  end
end

return M
