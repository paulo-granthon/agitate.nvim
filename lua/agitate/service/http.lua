local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.http')
if not types_ok then
  agitate_error.throw(types_or_err)
  error(types_or_err, 0)
end

---The GitHub REST API version this client is written against.
---Pinned deliberately: GitHub changes behaviour between versions, and an
---unpinned request follows whatever the default happens to be that week.
local API_VERSION = '2022-11-28'

---Escapes a value for use inside a double quoted curl config entry.
---
---curl reads its config a line at a time, so a carriage return or newline in
---the value would end the entry early and let the remainder be parsed as
---further config directives. They are stripped rather than escaped, because a
---credential legitimately containing one does not exist and silently carrying
---it through would only produce an auth failure nobody could diagnose.
---@param value string
---@return string
local function escape_config_value(value)
  return (value:gsub('[\r\n]', ''):gsub('\\', '\\\\'):gsub('"', '\\"'))
end

---Builds the curl configuration handed to the process on stdin.
---
---The access token lives here rather than in argv on purpose. `vim.system`
---takes an argument vector and never involves a shell, so there is no
---quoting hazard, but argv is still world readable through
---`/proc/<pid>/cmdline` for as long as the request is in flight. Anything
---running as the same user could read the token straight out of it. Passing
---it on stdin keeps it out of the process table entirely.
---@param token string|nil
---@return string
function M._build_config(token)
  local lines = {
    'silent',
    'show-error',
    'location',
    'header = "Accept: application/vnd.github+json"',
    'header = "X-GitHub-Api-Version: ' .. API_VERSION .. '"',
  }

  if token then
    lines[#lines + 1] = 'header = "Authorization: Bearer ' .. escape_config_value(token) .. '"'
  end

  return table.concat(lines, '\n') .. '\n'
end

---Builds the argument vector for a request.
---@param request HttpRequest
---@return string[] argv
function M._build_argv(request)
  local argv = {
    'curl',
    '--config',
    '-',
    '--request',
    request.method or 'GET',
    -- The status code is appended to the body on its own trailing line so a
    -- single stdout stream carries both. `--fail` is deliberately not used:
    -- GitHub puts the useful explanation in the body of a 4xx, and `--fail`
    -- would throw that body away.
    '--write-out',
    '\n%{http_code}',
  }

  if request.body ~= nil then
    -- curl defaults a request body to `application/x-www-form-urlencoded`,
    -- verified against httpbin. GitHub then reads the JSON as form fields and
    -- answers "Problems parsing JSON", so the header is not optional.
    argv[#argv + 1] = '-H'
    argv[#argv + 1] = 'Content-Type: application/json'
    argv[#argv + 1] = '--data-binary'
    argv[#argv + 1] = vim.json.encode(request.body)
  end

  argv[#argv + 1] = request.url

  return argv
end

---Splits curl's stdout into the response body and the trailing status code.
---@param stdout string
---@return string body
---@return number|nil status
function M._split_response(stdout)
  local lines = vim.split(stdout or '', '\n')
  local status = tonumber(table.remove(lines))

  return table.concat(lines, '\n'), status
end

---Performs an HTTP request asynchronously.
---
---The callback is always invoked, exactly once, and always on the main loop
---via `vim.schedule`. `vim.system` completes in a fast event context where
---most of the `vim.api` surface is off limits, so scheduling here means no
---caller has to remember to.
---
---@param request HttpRequest The request to perform
---@param callback fun(ok: boolean, result: HttpResponse|AgitateError) Completion handler
function M.request(request, callback)
  local argv = M._build_argv(request)

  local function finish(success, result)
    vim.schedule(function()
      callback(success, result)
    end)
  end

  local system_ok, system_err = pcall(vim.system, argv, {
    stdin = M._build_config(request.token),
    text = true,
  }, function(completed)
    -- A killed process reports `signal` with `code` left nil, so testing the
    -- code alone both misread that as an exit and concatenated nil into the
    -- message, replacing the real reason with a Lua error.
    if completed.signal ~= nil and completed.signal ~= 0 then
      return finish(false, {
        message = 'service.http -- Error: curl was terminated by signal ' .. tostring(completed.signal) .. '.',
      })
    end

    if completed.code ~= 0 then
      return finish(false, {
        message = 'service.http -- Error: curl exited with code '
          .. tostring(completed.code)
          .. '.\n'
          .. (completed.stderr ~= nil and completed.stderr ~= '' and completed.stderr or 'No error output.'),
      })
    end

    local raw, status = M._split_response(completed.stdout)

    if not status then
      return finish(false, {
        message = 'service.http -- Error: could not read a status code from the response.\nRaw output: ' .. raw,
      })
    end

    local decode_ok, decoded = pcall(vim.json.decode, raw)

    finish(true, {
      status = status,
      body = decode_ok and decoded or nil,
      raw = raw,
    })
  end)

  if not system_ok then
    finish(false, {
      message = 'service.http -- Error: could not start curl.\n' .. tostring(system_err),
    })
  end
end

---Builds a full GitHub API URL from a path.
---@param path string A path relative to the API root, with no leading slash
---@return string
function M.github_url(path)
  return 'https://api.github.com/' .. path
end

return M
