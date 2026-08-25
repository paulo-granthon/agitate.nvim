local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.api.nvim_err_writeln(require('agitate.const.error').import)
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
end

return M
