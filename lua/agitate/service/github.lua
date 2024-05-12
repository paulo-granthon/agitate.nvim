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
      .. [[","private":]]
      .. tostring(is_private)
      .. [["}']]
  )

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, repo_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    vim.api.nvim_err_writeln('post_new_repo -- Error: Empty json response after trim: `' .. flattened_github_response .. '`')

    return json_lr_trim_ok, error.unhandled('service.github.post_new_repo')
  end

  local json_decoded = vim.json.decode(repo_json)

  -- check if empty
  if json_decoded == nil or json_decoded == '' then
    vim.api.nvim_err_writeln('post_new_repo -- Error: Empty json response after decode: `' .. flattened_github_response .. '`')

    return false, error.unhandled('service.github.post_new_repo')
  else
    -- Return the processed response as a lua table
    return true, json_decoded
  end
end

function M.post_new_repo_v2(access_token, repository, is_private, path)
  local http = require('socket.http')
  local ltn12 = require('ltn12')
  local json = require('cjson')

  local response_body = {}
  local _, response_code = http.request({
    url = 'https://api.github.com/' .. path .. '/repos',
    method = 'POST',
    headers = {
      ['Authorization'] = 'token ' .. access_token,
      ['Content-Type'] = 'application/json',
    },
    source = ltn12.source.string(json.encode({
      name = repository,
      private = is_private,
    })),
    sink = ltn12.sink.table(response_body),
  })

  local response_body_json = json.decode(table.concat(response_body))

  if response_code ~= 201 then
    return false, response_body_json
  end

  return true, response_body_json
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
  local raw_github_response = util.execute_command(
    'curl'
      .. ' -L'
      .. ' -H '
      .. '"Authorization: token '
      .. access_token
      .. '"'
      .. ' -H'
      .. '"Accept: application/vnd.github+json"'
      .. ' https://api.github.com/orgs/'
      .. org
  )

  -- Flatten the table response to string
  local flattened_github_response = util.flatten_table(raw_github_response)

  -- Trim any noise left of the first `{` or right of the last `}`
  local json_lr_trim_ok, org_json = util.json_lr_trim(flattened_github_response)
  if not json_lr_trim_ok then
    return json_lr_trim_ok, error.unhandled('service.github.get_organization')
  end

  -- Return the processed response as a lua table
  local json_decoded = vim.json.decode(org_json)

  if json_decoded == nil or json_decoded == '' then
    return false, error.unhandled('service.github.get_organization')
  end

  if json_decoded.message then
    if json_decoded.message == 'Not Found' then
      return false, error.unhandled('service.github.get_organization')
    end

    return false, error.throw('service.github.get_organization -- Error:' .. json_decoded.message)
  end

  return true, json_decoded
end

return M
