local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local http_ok, http_or_err = pcall(require, 'agitate.service.http')
if not http_ok then
  agitate_error.throw(http_or_err)
  error(http_or_err, 0)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.github')
if not types_ok then
  agitate_error.throw(types_or_err)
  error(types_or_err, 0)
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
  -- A JSON body is usually an object, but a proxy or a malformed endpoint can
  -- return a bare number or string, and indexing one of those throws while
  -- trying to format the very error being reported.
  local body = type(response.body) == 'table' and response.body or {}
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

---Performs a request and hands back the decoded body on the expected status.
---
---Every GitHub endpoint Agitate uses has the same shape: succeed on one
---status, otherwise explain what went wrong. Sharing that keeps the handling
---in one place rather than repeating it once per endpoint.
---
---@param access_token string|nil Your GitHub PAT, optional for public endpoints
---@param request table `{ path = string, method = string|nil, body = table|nil }`
---@param action string What was being attempted, phrased to follow "could not"
---@param expected number The status that means success
---@param callback fun(ok: boolean, result: table|AgitateError) Completion handler
function M.call(access_token, request, action, expected, callback)
  http.request({
    url = http.github_url(request.path),
    method = request.method,
    token = access_token,
    body = request.body,
  }, function(request_ok, response)
    if not request_ok then
      return callback(false, response)
    end

    if response.status ~= expected then
      return callback(false, { message = M.describe_failure(action, response) })
    end

    -- `== nil` rather than falsey: `false` is valid JSON and decodes to a
    -- Lua false, which a truthiness test would reject as "not JSON".
    if response.body == nil then
      return callback(false, { message = 'service.github -- Error: expected JSON from `' .. request.path .. '`.\nRaw response: ' .. response.raw })
    end

    callback(true, response.body)
  end)
end

---Performs a plain GET, succeeding on 200.
---@param access_token string|nil
---@param path string
---@param action string
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.get(access_token, path, action, callback)
  M.call(access_token, { path = path }, action, 200, callback)
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

    -- A 200 alone is not enough. The transport reports `body = nil` when the
    -- response was not JSON, which a proxy or an outage page can produce, and
    -- treating that as an organization would create the repository under
    -- `orgs/<name>` on the strength of an HTML error page.
    if response.status == 200 then
      -- `== nil` rather than falsey: `false` is valid JSON and decodes to a
      -- Lua false, which a truthiness test would reject as "not JSON".
      if response.body == nil then
        return callback(false, {
          message = 'service.github.is_organization -- Error: expected JSON from the organization lookup.\nRaw response: ' .. response.raw,
        })
      end

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
  M.call(
    access_token,
    {
      path = options.path .. '/repos',
      method = 'POST',
      body = {
        name = options.name,
        private = options.is_private,
      },
    },
    'create the repository `' .. options.name .. '`',
    201,
    function(created_ok, result)
      if not created_ok then
        return callback(false, result)
      end

      if not result.html_url then
        return callback(false, {
          message = 'service.github.create_repository -- Error: GitHub reported success but returned no `html_url`.',
        })
      end

      callback(true, result)
    end
  )
end

---Changes the visibility of an existing repository.
---@param access_token string Your GitHub PAT
---@param owner string The user or organization owning the repository
---@param repository string The repository name
---@param is_private boolean `true` makes the repository private, `false` public
---@param callback fun(ok: boolean, result: table|AgitateError) Completion handler
function M.set_repository_visibility(access_token, owner, repository, is_private, callback)
  M.call(access_token, {
    path = 'repos/' .. owner .. '/' .. repository,
    method = 'PATCH',
    body = { private = is_private },
  }, 'change the visibility of `' .. owner .. '/' .. repository .. '`', 200, callback)
end

return M
