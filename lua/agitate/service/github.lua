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

---GitHub's hard ceiling for a page of results.
local PER_PAGE = 100

---How many pages a list command will walk before reporting a truncated list.
local MAX_PAGES = 10

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

      -- Type checked: the transport allows any JSON type, so a valid but
      -- unexpected body such as a bare string would raise on indexing rather
      -- than be reported as a malformed success.
      if type(result) ~= 'table' or not result.html_url then
        return callback(false, {
          message = 'service.github.create_repository -- Error: GitHub reported success but returned no `html_url`.',
        })
      end

      callback(true, result)
    end
  )
end

---Fetches every page of a list endpoint.
---
---GitHub caps a page at 100 regardless of what is asked for, so a single
---request silently truncates any longer list. Pages until a short page comes
---back, which is how the API signals the end.
---
---Bounded at `MAX_PAGES`. A repository large enough to hit that is possible,
---and stopping silently would read as "this is everything", so hitting the
---bound notifies the user. It is not signalled to the caller: the result is
---still `ok` with a partial list, because every caller wants to display what
---it has rather than fail.
---@param access_token string|nil
---@param path string An API path, with or without an existing query string
---@param action string
---@param callback fun(ok: boolean, result: table[]|AgitateError)
function M.get_all(access_token, path, action, callback)
  local collected = {}
  local separator = path:find('?', 1, true) and '&' or '?'

  local function fetch(page)
    M.get(access_token, path .. separator .. 'per_page=' .. PER_PAGE .. '&page=' .. page, action, function(page_ok, result)
      if not page_ok then
        return callback(false, result)
      end

      -- An object such as `{ "message": ... }` is a table with no array part,
      -- so it read as a short page and came back as `ok` with an empty list.
      -- An empty JSON array is also an empty table, hence the `next` check
      -- rather than a length one.
      if type(result) ~= 'table' or (next(result) ~= nil and result[1] == nil) then
        return callback(false, {
          message = 'service.github -- Error: expected a list from `' .. path .. '`, got ' .. vim.inspect(result, { newline = ' ', indent = '' }):sub(1, 200),
        })
      end

      for _, item in ipairs(result) do
        collected[#collected + 1] = item
      end

      if #result < PER_PAGE then
        return callback(true, collected)
      end

      if page >= MAX_PAGES then
        vim.notify('Agitate: showing the first ' .. #collected .. ' results only, there are more.', vim.log.levels.WARN)

        return callback(true, collected)
      end

      fetch(page + 1)
    end)
  end

  fetch(1)
end

---Fetches the comments on an issue or pull request.
---
---GitHub models a pull request as an issue for conversation comments, so this
---one function serves both and neither feature needs its own.
---@param access_token string
---@param owner string
---@param repository string
---@param number number The issue or pull request number
---@param callback fun(ok: boolean, result: table[]|AgitateError)
function M.list_comments(access_token, owner, repository, number, callback)
  M.get_all(access_token, 'repos/' .. owner .. '/' .. repository .. '/issues/' .. number .. '/comments', 'read the comments on #' .. number, callback)
end

---Fetches a repository, which is how the default branch is discovered.
---@param access_token string
---@param owner string
---@param repository string
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.get_repository(access_token, owner, repository, callback)
  M.get(access_token, 'repos/' .. owner .. '/' .. repository, 'read `' .. owner .. '/' .. repository .. '`', callback)
end

---Adds a comment to an issue or a pull request.
---
---GitHub models a pull request as an issue for commenting, so both go through
---this one endpoint and neither needs its own.
---@param access_token string
---@param owner string
---@param repository string
---@param number number The issue or pull request number
---@param body string The comment text
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.create_comment(access_token, owner, repository, number, body, callback)
  M.call(access_token, {
    path = 'repos/' .. owner .. '/' .. repository .. '/issues/' .. number .. '/comments',
    method = 'POST',
    body = { body = body },
  }, 'comment on `' .. owner .. '/' .. repository .. '#' .. number .. '`', 201, callback)
end

---Lists the issues of a repository.
---
---GitHub's issues endpoint also returns pull requests, which is a long
---standing quirk of the API rather than something the caller asked for. Any
---entry carrying a `pull_request` key is one, and is filtered out here so an
---issue list is only issues.
---@param access_token string
---@param owner string
---@param repository string
---@param state string `open`, `closed` or `all`
---@param callback fun(ok: boolean, result: table[]|AgitateError)
function M.list_issues(access_token, owner, repository, state, callback)
  M.get_all(
    access_token,
    'repos/' .. owner .. '/' .. repository .. '/issues?state=' .. state,
    'list the issues of `' .. owner .. '/' .. repository .. '`',
    function(list_ok, result)
      if not list_ok then
        return callback(false, result)
      end

      local issues = {}

      for _, entry in ipairs(result) do
        if not entry.pull_request then
          issues[#issues + 1] = entry
        end
      end

      callback(true, issues)
    end
  )
end

---Fetches a single issue.
---@param access_token string
---@param owner string
---@param repository string
---@param number number
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.get_issue(access_token, owner, repository, number, callback)
  M.get(access_token, 'repos/' .. owner .. '/' .. repository .. '/issues/' .. number, 'read issue #' .. number, callback)
end

---Opens a new issue.
---@param access_token string
---@param owner string
---@param repository string
---@param issue table `{ title = string, body = string }`
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.create_issue(access_token, owner, repository, issue, callback)
  M.call(
    access_token,
    {
      path = 'repos/' .. owner .. '/' .. repository .. '/issues',
      method = 'POST',
      body = { title = issue.title, body = issue.body },
    },
    'open an issue on `' .. owner .. '/' .. repository .. '`',
    201,
    function(created_ok, result)
      if not created_ok then
        return callback(false, result)
      end

      -- The caller reports the new issue by concatenating both of these, so a
      -- success missing either would crash while announcing itself.
      -- Type checked: the transport allows any JSON type, so a valid body that
      -- decoded to a string or a boolean would raise on the index rather than be
      -- reported as the malformed success it is. `create_repository` already does
      -- this; the two are the same check.
      if type(result) ~= 'table' or not result.number or not result.html_url then
        return callback(false, {
          message = 'service.github.create_issue -- Error: GitHub reported success but returned no `number` or `html_url`.',
        })
      end

      callback(true, result)
    end
  )
end

---Opens or closes an issue.
---@param access_token string
---@param owner string
---@param repository string
---@param number number
---@param state string `open` or `closed`
---@param callback fun(ok: boolean, result: table|AgitateError)
function M.set_issue_state(access_token, owner, repository, number, state, callback)
  M.call(access_token, {
    path = 'repos/' .. owner .. '/' .. repository .. '/issues/' .. number,
    method = 'PATCH',
    body = { state = state },
  }, (state == 'closed' and 'close' or 'reopen') .. ' issue #' .. number, 200, callback)
end

return M
