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

---Creates a new remote repository through the GitHub API
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param repository string Name of the repository to be created
---@return boolean Ok If proccess was executed successfully
---Response properly formatted for the rest of `agitated.nvim`
---@return GitHubNewRepoSuccessResponse|GitHubErrorResponse|AgitateError Response
function M.post_new_repo(access_token, repository)
  -- Execute curl to create the repository through the GitHub api
  local raw_github_response = util.execute_command(
    'curl'
      .. ' -H '
      .. '"Authorization: token '
      .. access_token
      .. '"'
      .. ' https://api.github.com/user/repos'
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

return M
