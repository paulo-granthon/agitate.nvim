local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

local types_ok, types_or_err = pcall(require, 'agitate.types.http')
if not types_ok then
  return agitate_error.throw(types_or_err)
end

---The GitHub REST API version this client is written against.
---Pinned deliberately: GitHub changes behaviour between versions, and an
---unpinned request follows whatever the default happens to be that week.
local API_VERSION = '2022-11-28'

---Escapes a value for use inside a double quoted curl config entry.
---curl understands the usual backslash escapes there, so a literal
---backslash and a literal quote are all that need handling.
---@param value string
---@return string
local function escape_config_value(value)
  return (value:gsub('\\', '\\\\'):gsub('"', '\\"'))
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
    if completed.code ~= 0 then
      return finish(false, {
        message = 'service.http -- Error: curl exited with code '
          .. completed.code
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
