local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
  return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

function M.setup()
  vim.api.nvim_create_user_command('AgitateRepoCreateGitHub', function(opts)
    local repo_ok, repo_or_err = pcall(require, 'agitate.core.repo')
    if not repo_ok then
      return error.throw(repo_or_err)
    end

    repo_or_err.CreateGitHubCurl(opts.fargs and { opts.fargs[1] } or nil)
  end, {
    nargs = '?',
    desc = "Creates a new repository at 'github.com/<github_username>/<argument or current_directory>/'",
  })

  vim.api.nvim_create_user_command('AgitateRepoInitGitHub', function(opts)
    local repo_ok, repo_or_err = pcall(require, 'agitate.core.repo')
    if not repo_ok then
      return error.throw(repo_or_err)
    end

    repo_or_err.InitGitHub(opts.fargs and opts.fargs[1] or nil)
  end, {
    nargs = '?',
    desc = "Initialize the current directory as a repository at 'github.com/<github_username>/<argument or current_directory>/'",
  })
end

return M
