local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
  return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

local util_ok, util_or_err = pcall(require, 'agitate.util')
if not util_ok then
  return error.throw(util_or_err)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.github')
if not types_ok then
  return error.throw(types_or_err)
end

local util = util_or_err

---Creates a new remote repository on GitHub
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param repository string Name of the repository to be created
---@return boolean Ok If proccess was executed successfully
---@return GitHubNewRepoSuccessResponse|GitHubErrorResponse|AgitateError Response
---Response properly formatted for the rest of `agitated.nvim`.
---Might contain the repo information relavant to the rest of Agitate or an error message
---@see GitHubNewRepoSuccessResponse
---@see GitHubErrorResponse
---@see AgitateError
function M.post_new_repo(access_token, repository, path)
  -- Execute curl to create the repository through the GitHub api
  local raw_github_response = util.execute_command(
    'curl'
      .. ' -H '
      .. '"Authorization: token '
      .. access_token
      .. '" '
      .. 'https://api.github.com/'
      .. path
      .. '/repos'
      .. ' -d '
      .. [['{"name":"]]
      .. repository
      .. [["}']]
  )

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, repo_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    return json_lr_trim_ok, error.unhandled('service.github.post_new_repo')
  end

  -- Return the processed response as a lua table
  return true, vim.json.decode(repo_json)
end

---Get information about an organization on GitHub
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param organization string Name of the organization to get information about
---@return boolean Ok If proccess was executed successfully
---@return GitHubGetOrgSuccessResponse|GitHubErrorResponse|AgitateError Response
---Response properly formatted for the rest of `agitated.nvim`.
---Might contain the organization information relavant to the rest of Agitate or an error message
---@see GitHubGetOrgSuccessResponse
---@see GitHubErrorResponse
---@see AgitateError
function M.get_organization(access_token, organization)
  -- Execute curl to get the organization information through the GitHub api
  local raw_github_response =
    util.execute_command('curl' .. ' -H ' .. '"Authorization: token ' .. access_token .. '"' .. ' https://api.github.com/orgs/' .. organization)

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, org_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    return json_lr_trim_ok, error.unhandled('service.github.get_organization')
  end

  -- Return the processed response as a lua table
  return true, vim.json.decode(org_json)
end

return M
