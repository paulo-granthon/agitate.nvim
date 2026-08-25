local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

local http_ok, http_or_err = pcall(require, 'agitate.service.http')
if not http_ok then
  return agitate_error.throw(http_or_err)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.github')
if not types_ok then
  return agitate_error.throw(types_or_err)
end

local http = http_or_err

---Builds a readable message from a GitHub error response.
---
---GitHub reports a failure in two layers: a top level `message` describing
---what went wrong, and an optional `errors` array explaining which field
---caused it. The second layer carries the part a user can act on, such as
---`name already exists on this account`, so both are surfaced.
---@param action string What was being attempted, phrased to follow "could not"
---@param response HttpResponse The response that failed
---@return string
function M.describe_failure(action, response)
  local body = response.body or {}
  local reasons = {}

  if body.message then
    reasons[#reasons + 1] = body.message
  end

  for _, err in ipairs(body.errors or {}) do
    reasons[#reasons + 1] = err.message or vim.inspect(err)
  end

  if #reasons == 0 then
    reasons[#reasons + 1] = response.raw ~= '' and response.raw or 'GitHub gave no reason.'
  end

  return 'GitHub could not ' .. action .. '.\nHTTP ' .. response.status .. ': ' .. table.concat(reasons, '\n')
end

---Determines whether a name belongs to an organization rather than a user.
---
---A 404 is the ordinary answer for a personal account, not a failure, so it
---resolves to `false` rather than an error. Anything else, an expired token
---or a rate limit for instance, is reported, because silently treating it as
---"not an organization" would create the repository in the wrong place.
---@param access_token string Your GitHub PAT
---@param name string The user or organization name to test
---@param callback fun(ok: boolean, result: boolean|AgitateError) Completion handler
function M.is_organization(access_token, name, callback)
  http.request({
    url = http.github_url('orgs/' .. name),
    token = access_token,
  }, function(request_ok, response)
    if not request_ok then
      return callback(false, response)
    end

    if response.status == 200 then
      return callback(true, true)
    end

    if response.status == 404 then
      return callback(true, false)
    end

    callback(false, { message = M.describe_failure('look up `' .. name .. '`', response) })
  end)
end

---Creates a new remote repository on GitHub.
---@param access_token string Your GitHub PAT
---@param options CreateRepositoryOptions Where and what to create
---@param callback fun(ok: boolean, result: GitHubNewRepoSuccessResponse|AgitateError) Completion handler
function M.create_repository(access_token, options, callback)
  http.request({
    url = http.github_url(options.path .. '/repos'),
    method = 'POST',
    token = access_token,
    body = {
      name = options.name,
      private = options.is_private,
    },
  }, function(request_ok, response)
    if not request_ok then
      return callback(false, response)
    end

    if response.status ~= 201 then
      return callback(false, { message = M.describe_failure('create the repository `' .. options.name .. '`', response) })
    end

    if not response.body or not response.body.html_url then
      return callback(false, {
        message = 'service.github.create_repository -- Error: GitHub reported success but returned no `html_url`.\nRaw response: ' .. response.raw,
      })
    end

    callback(true, response.body)
  end)
end

return M
