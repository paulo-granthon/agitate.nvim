local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
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

  local file_ok, file_or_err = pcall(require, 'agitate.api.file')
  if file_ok then
    file_or_err.setup()
  else
    agitate_error.throw(file_or_err)
  end
end

return M
