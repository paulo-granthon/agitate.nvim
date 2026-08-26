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

local types_ok, types_or_err = pcall(require, 'agitate.types.github')
if not types_ok then
  agitate_error.throw(types_or_err)
  error(types_or_err, 0)
end

local util = util_or_err

---Creates a new remote repository on GitHub
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param repository string Name of the repository to be created
---@param is_private boolean Whether the repository should be private or public
---@return boolean Ok If proccess was executed successfully
---@return GitHubNewRepoSuccessResponse|GitHubErrorResponse|AgitateError Response
---Response properly formatted for the rest of `agitated.nvim`.
---Might contain the repo information relavant to the rest of Agitate or an error message
---@see GitHubNewRepoSuccessResponse
---@see GitHubErrorResponse
---@see AgitateError
function M.post_new_repo(access_token, repository, is_private, path)
  -- Execute curl to create the repository through the GitHub api
  -- An argument vector rather than one string. `vim.fn.systemlist` runs a
  -- string through a shell, so the token, repository name and path were all
  -- interpolated unescaped into a shell command. A list bypasses the shell
  -- entirely, and `vim.json.encode` removes the hand built JSON quoting that
  -- produced a malformed body once already.
  local raw_github_response = util.execute_command({
    'curl',
    '--silent',
    '--show-error',
    -- An argv list bypasses the shell, so curl's stderr is otherwise dropped
    -- and a failed request produced an empty body with no explanation.
    '--stderr',
    '-',
    '-H',
    'Authorization: token ' .. access_token,
    '-H',
    'Accept: application/vnd.github+json',
    'https://api.github.com/' .. path .. '/repos',
    '-d',
    vim.json.encode({ name = repository, private = is_private }),
  })

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, repo_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    vim.notify('post_new_repo -- Error: Empty json response after trim: `' .. flattened_github_response .. '`', vim.log.levels.ERROR)

    return json_lr_trim_ok, agitate_error.unhandled('service.github.post_new_repo')
  end

  -- `vim.json.decode` raises on malformed input, and curl can emit a
  -- partial body or a proxy error page. Raising here would crash the
  -- command instead of returning the documented (ok, response) pair.
  local decode_ok, json_decoded = pcall(vim.json.decode, repo_json)

  if not decode_ok then
    return false,
      {
        message = 'service.github.post_new_repo -- Error: could not decode the response.\n'
          .. tostring(json_decoded)
          .. '\nResponse: '
          .. flattened_github_response,
      }
  end

  -- check if empty
  if json_decoded == nil or json_decoded == '' then
    vim.notify('post_new_repo -- Error: Empty json response after decode: `' .. flattened_github_response .. '`', vim.log.levels.ERROR)

    return false, agitate_error.unhandled('service.github.post_new_repo')
  else
    -- Return the processed response as a lua table
    return true, json_decoded
  end
end

---Get information about an organization on GitHub
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param org string Name of the organization to get information about
---@return boolean Ok If proccess was executed successfully
---@return GitHubGetOrgSuccessResponse|GitHubErrorResponse|AgitateError Response
---Response properly formatted for the rest of `agitated.nvim`.
---Might contain the organization information relavant to the rest of Agitate or an error message
---@see GitHubGetOrgSuccessResponse
---@see GitHubErrorResponse
---@see AgitateError
function M.get_organization(access_token, org)
  -- Execute curl to get the organization information through the GitHub api
  local raw_github_response = util.execute_command({
    'curl',
    '--silent',
    '--show-error',
    -- An argv list bypasses the shell, so curl's stderr is otherwise dropped
    -- and a failed request produced an empty body with no explanation.
    '--stderr',
    '-',
    '--location',
    '-H',
    'Authorization: token ' .. access_token,
    '-H',
    'Accept: application/vnd.github+json',
    'https://api.github.com/orgs/' .. org,
  })

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, org_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    return json_lr_trim_ok, agitate_error.unhandled('service.github.get_organization')
  end

  -- Return the processed response as a lua table
  -- `vim.json.decode` raises on malformed input, and curl can emit a
  -- partial body or a proxy error page. Raising here would crash the
  -- command instead of returning the documented (ok, response) pair.
  local decode_ok, json_decoded = pcall(vim.json.decode, org_json)

  if not decode_ok then
    return false,
      {
        message = 'service.github.get_organization -- Error: could not decode the response.\n'
          .. tostring(json_decoded)
          .. '\nResponse: '
          .. flattened_github_response,
      }
  end

  if json_decoded == nil or json_decoded == '' then
    return false, agitate_error.unhandled('service.github.get_organization')
  end

  if json_decoded.message then
    -- A 404 is how GitHub says "this name is a user", which is the common
    -- case rather than a failure. Returning `unhandled` labelled it as a
    -- defect in Agitate and made the error channel useless for real problems.
    if json_decoded.message == 'Not Found' then
      return false, json_decoded
    end

    return false, { message = 'service.github.get_organization -- Error: ' .. json_decoded.message }
  end

  return true, json_decoded
end

return M
