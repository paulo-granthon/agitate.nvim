local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

function M.setup()
  vim.api.nvim_create_user_command('AgitateRepoCreate', function(opts)
    local repo_ok, repo_or_err = pcall(require, 'agitate.core.repo')
    if not repo_ok then
      return agitate_error.throw(repo_or_err)
    end

    repo_or_err.Create(opts.fargs)
  end, {
    nargs = '*',
    desc = "Creates a new repository at 'github.com/<github_username>/<argument or current_directory>/'",
  })

  vim.api.nvim_create_user_command('AgitateRepoInit', function(opts)
    local repo_ok, repo_or_err = pcall(require, 'agitate.core.repo')
    if not repo_ok then
      return agitate_error.throw(repo_or_err)
    end

    repo_or_err.Init(opts.fargs)
  end, {
    nargs = '*',
    desc = "Initialize the current directory as a repository at 'github.com/<github_username>/<argument or current_directory>/'",
  })
end

return M
