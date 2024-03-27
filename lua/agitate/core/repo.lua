local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
  return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

local util_ok, util_or_err = pcall(require, 'agitate.util')
if not util_ok then
  return error.throw(util_or_err)
end

local github_ok, github_or_err = pcall(require, 'agitate.service.github')
if not github_ok then
  return error.throw(github_or_err)
end

local util = util_or_err
local github = github_or_err

---Create a new repository on GitHub
---@param optional_parameters? table<string> The value at each index depends on the number of parameters passed:
--- 1 optional_parameter: The name of the repository to create.
--- 2 optional_parameters: The first value is the GitHub username or organization
---    and the second is the name of the repository to create.
---
--- Defaults: [1] GitHub username from config, [2] Current directory name.
function M.CreateGitHubCurl(optional_parameters)
  local options = require('agitate.config').options

  local new_github_repository_name = util.get_directory_name()
  local github_username = options.github_username

  if optional_parameters then
    if #optional_parameters == 1 then
      new_github_repository_name = optional_parameters[1] or new_github_repository_name
    elseif #optional_parameters == 2 then
      github_username = optional_parameters[1] or github_username
      new_github_repository_name = optional_parameters[2] or new_github_repository_name
    end
  end

  local github_access_token = options.github_access_token

  if not github_username or not github_access_token then
    return error('Agitate | CreateGitHubCurl | Error - Undefined GitHub Username or Access Token')
  end

  local github_post_ok, github_post_response = github.post_new_repo(github_access_token, new_github_repository_name)

  if not github_post_ok then
    error.throw(github_post_response)
  end

  if github_post_response.errors then
    return vim.api.nvim_err_writeln(
      'Agitate | CreateGitHubCurl | Error:'
        .. '\nFailed to create repository at '
        .. ' `https://github.com/'
        .. github_username
        .. '/'
        .. new_github_repository_name
        .. '/`'
        .. '\nReason: `'
        .. github_post_response.errors[1].message
        .. '`'
    )
  end

  print(
    'Created remote GitHub repository at '
      .. github_post_response.html_url
      .. '\nYou can initialize the current directory to this remote origin with `:AgitateRepoInitGitHub '
      .. new_github_repository_name
      .. '`'
  )
end

---Initialize a new repository and push to GitHub
---@param optional_parameters? table<string> The value at each index depends on the number of parameters passed:
--- 1 optional_parameter: The name of the repository to create.
--- 2 optional_parameters: The first value is the GitHub username or organization
---    and the second is the name of the repository to create.
---
--- Defaults: [1] GitHub username from config, [2] Current directory name.
function M.InitGitHub(optional_parameters)
  local options = require('agitate.config').options

  local github_repository_name = util.get_directory_name()
  local github_username = options.github_username

  if optional_parameters then
    if #optional_parameters == 1 then
      github_repository_name = optional_parameters[1] or github_repository_name
    elseif #optional_parameters == 2 then
      github_username = optional_parameters[1] or github_username
      github_repository_name = optional_parameters[2] or github_repository_name
    end
  end


  util.execute_command('echo "# ' .. github_repository_name .. '" >> README.md')
  vim.cmd('G init')
  vim.cmd('G add README.md')
  vim.cmd('G commit -m "' .. options.repo.init.first_commit_message .. '"')
  vim.cmd('G branch -M main')
  vim.cmd('G remote add origin https://github.com/' .. github_username .. '/' .. github_repository_name .. '.git')
  vim.cmd('G push -u origin main')

  -- Open fugitive status window
  if options.repo.init.show_status then
    vim.cmd('G')
  end
end

return M
