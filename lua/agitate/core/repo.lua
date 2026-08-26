local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local util_ok, util_or_err = pcall(require, 'agitate.util')
if not util_ok then
  agitate_error.throw(util_or_err)
  error(util_or_err, 0)
end

local github_ok, github_or_err = pcall(require, 'agitate.service.github')
if not github_ok then
  agitate_error.throw(github_or_err)
  error(github_or_err, 0)
end

local util = util_or_err
local github = github_or_err

local parse_args = require('agitate.parse_args')

---Create a new repository on GitHub
---@param optional_parameters? table<string> Parameters can be passed in order or explicitly
---with their corresponding flags:
---  -r: The name of the repository to create.
---  -u: The GitHub username or organization to create the repository under.
---  -v: The visibility of the repository. Can be 'public' or 'private'.
---Defaults:
---  -u: GitHub username from config
---  -r: Current directory name
---  -v: 'public'
function M.Create(optional_parameters)
  local options = require('agitate.config').options

  local parameters, leftover, incomplete = parse_args({
    '-r',
    '-u',
    '-v',
  }, optional_parameters)

  if #incomplete > 0 then
    return agitate_error.throw('core.repo.Create -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw('core.repo.Create -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local repository_name = parameters['-r'] or util.get_directory_name()
  local github_username = parameters['-u'] or options.github_username
  local is_private = parameters['-v'] == 'private'

  local github_access_token = options.github_access_token

  if not github_username or not github_access_token then
    return agitate_error.throw('core.repo.Create -- Error: undefined GitHub username or access token')
  end

  local path = 'user'

  local is_org, _ = github.get_organization(github_access_token, github_username)

  if is_org then
    vim.notify(
      (is_private and 'Private repository ' or 'Repository ') .. repository_name .. ' will be created under organization ' .. github_username,
      vim.log.levels.INFO
    )
    path = 'orgs/' .. github_username
  else
    vim.notify(
      (is_private and 'Private repository ' or 'Repository ') .. repository_name .. ' will be created under user ' .. github_username,
      vim.log.levels.INFO
    )
  end

  local github_post_ok, github_post_response = github.post_new_repo(github_access_token, repository_name, is_private, path)

  if not github_post_ok then
    return agitate_error.throw(github_post_response)
  end

  if github_post_response.errors then
    local first_error = github_post_response.errors[1]

    return agitate_error.throw(
      'core.repo.Create -- Error: failed to create repository at '
        .. util.build_github_html_url(github_username, repository_name)
        .. '\nReason: '
        .. ((first_error and first_error.message) or vim.inspect(github_post_response.errors))
    )
  end

  if not github_post_response.html_url then
    return agitate_error.throw(
      'core.repo.Create -- Error: repository creation at '
        .. util.build_github_html_url(github_username, repository_name)
        .. ' returned no `html_url`.'
        .. '\nFull response: '
        .. vim.inspect(github_post_response)
    )
  end

  vim.notify(
    'Created remote GitHub repository at '
      .. github_post_response.html_url
      .. '\nYou can initialize the current directory to this remote origin with `:AgitateRepoInit '
      .. repository_name
      .. '`',
    vim.log.levels.INFO
  )
end

---Initialize a new repository and push to GitHub
---@param optional_parameters? table<string> The value at each index depends on the number of parameters passed:
--- 1 optional_parameter: The name of the repository to create.
--- 2 optional_parameters: The first value is the GitHub username or organization
---    and the second is the name of the repository to create.
---
--- Defaults: [1] GitHub username from config, [2] Current directory name.
function M.Init(optional_parameters)
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

  if not github_username or not github_repository_name then
    return agitate_error.throw('core.repo.Init -- Error: undefined GitHub username or repository name')
  end

  util.execute_command('echo "# ' .. github_repository_name .. '" >> README.md')
  vim.cmd('G init')
  vim.cmd('G add README.md')
  vim.cmd('G commit -m "' .. options.repo.init.first_commit_message .. '"')
  vim.cmd('G branch -M main')
  vim.cmd('G remote add origin ' .. util.build_github_html_url(github_username, github_repository_name) .. '.git')
  vim.cmd('G push -u origin main')

  -- Open fugitive status window
  if options.repo.init.show_status then
    vim.cmd('G')
  end
end

return M
