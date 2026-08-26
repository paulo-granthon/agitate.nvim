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
---@param optional_parameters? string[] Parameters can be passed in order or explicitly
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
  local visibility = parameters['-v']

  -- Validated rather than compared. Anything other than the exact string
  -- `private` used to mean public, so `-v privte` silently created a public
  -- repository, which is the one mistake here that cannot be taken back.
  if visibility and visibility ~= 'public' and visibility ~= 'private' then
    return agitate_error.throw('core.repo.Create -- Error: `-v` expects `public` or `private`, got `' .. visibility .. '`')
  end

  local is_private = visibility == 'private'

  local github_access_token = options.github_access_token

  if not github_username or not github_access_token then
    return agitate_error.throw('core.repo.Create -- Error: undefined GitHub username or access token')
  end

  local path = 'user'

  -- Only a 404 means "this name is a user". Bad credentials, a rate limit or
  -- a decode failure also return false, and treating those as a user posts the
  -- repository to `user/repos` on a guess.
  local is_org, org_result = github.get_organization(github_access_token, github_username)

  if not is_org and org_result and org_result.message and org_result.message ~= 'Not Found' then
    return agitate_error.throw(org_result)
  end

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

  -- Checked before the html_url branch: an error body without an `errors`
  -- array, such as `{"message":"Bad credentials"}`, otherwise fell through and
  -- was reported as a missing `html_url`, hiding what GitHub actually said.
  if github_post_response.message and not github_post_response.html_url then
    return agitate_error.throw(
      'core.repo.Create -- Error: failed to create repository at '
        .. util.build_github_html_url(github_username, repository_name)
        .. '\nReason: '
        .. github_post_response.message
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

---Initialize the current directory as a repository and push it to GitHub
---@param optional_parameters? string[] Parameters can be passed in order or explicitly
---with their corresponding flags:
---  -r: The name of the repository. Defaults to the current directory name.
---  -u: The GitHub username or organization. Defaults to the configured username.
function M.Init(optional_parameters)
  local options = require('agitate.config').options

  local parameters, leftover, incomplete = parse_args({
    '-r',
    '-u',
  }, optional_parameters)

  if #incomplete > 0 then
    return agitate_error.throw('core.repo.Init -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw('core.repo.Init -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local github_repository_name = parameters['-r'] or util.get_directory_name()
  local github_username = parameters['-u'] or options.github_username

  -- An empty string passes a nil check but produces an invalid URL and an
  -- invalid git command, so `-r ""` has to be rejected here rather than
  -- surfacing later as a confusing failure.
  if not github_username or github_username == '' or not github_repository_name or github_repository_name == '' then
    return agitate_error.throw('core.repo.Init -- Error: undefined GitHub username or repository name')
  end

  -- The option is documented and typed as optional, so an absent value means
  -- the default rather than a mistake. Only a value that is present and wrong
  -- is worth refusing.
  -- `== nil` rather than `or`: only an absent value means the default. `or`
  -- also swallowed `false`, which is a misconfiguration the check below exists
  -- to report.
  local protocol = options.repo.init.remote_protocol
  if protocol == nil then
    protocol = 'https'
  end

  if protocol ~= 'https' and protocol ~= 'ssh' then
    return agitate_error.throw('core.repo.Init -- Error: `repo.init.remote_protocol` expects `https` or `ssh`, got `' .. tostring(protocol) .. '`')
  end

  -- Written directly rather than shelled out to `echo ... >> README.md`, which
  -- ran through a shell with the repository name interpolated unescaped. The
  -- result is checked, so a readonly directory is reported here rather than
  -- surfacing as a confusing `git add` failure two steps later.
  if vim.fn.writefile({ '# ' .. github_repository_name }, 'README.md', 'a') ~= 0 then
    return agitate_error.throw('core.repo.Init -- Error: could not write README.md')
  end
  -- Run through git directly rather than `:G`. Every one of these
  -- interpolated a value into an Ex command line: the commit message is user
  -- configured and a `"` in it broke the quoting, while `|` in any of them is
  -- an Ex separator that would run the remainder as a second command. An
  -- argument vector is parsed by neither Ex nor a shell.
  -- Defaulted rather than passed through: the option is optional, and a nil
  -- would produce `git commit -m` with no message and a git usage error that
  -- says nothing about Agitate's configuration.
  local commit_message = options.repo.init.first_commit_message
  if type(commit_message) ~= 'string' or commit_message == '' then
    commit_message = 'first commit'
  end

  local steps = {
    { 'init' },
    { 'add', 'README.md' },
    { 'commit', '-m', commit_message },
    { 'branch', '-M', 'main' },
    { 'remote', 'add', 'origin', util.build_github_remote_url(github_username, github_repository_name, protocol) },
    { 'push', '-u', 'origin', 'main' },
  }

  -- Explicitly the working directory, not the buffer's. `Init` initialises the
  -- directory the user is in, and its README is written relative to `getcwd()`,
  -- so letting git resolve the buffer's directory instead would split one
  -- command across two places: README here, `git init` there.
  local directory = vim.fn.getcwd()

  for _, step in ipairs(steps) do
    local output, step_ok = util.git(step, directory)

    if not step_ok then
      return agitate_error.throw('core.repo.Init -- Error: `git ' .. table.concat(step, ' ') .. '` failed.\n' .. table.concat(output, '\n'))
    end
  end

  -- Open fugitive status window
  if options.repo.init.show_status then
    vim.cmd('G')
  end
end

return M
