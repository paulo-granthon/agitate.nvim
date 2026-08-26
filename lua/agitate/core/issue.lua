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

local editor = require('agitate.ui.buffer')
local list = require('agitate.ui.list')
local document = require('agitate.ui.document')
local parse_args = require('agitate.parse_args')

---Resolves the repository and token every issue command needs.
---
---Defaults to the checkout the user is sitting in, so the common case needs no
---arguments at all.
---@param parameters table<string, string> Parsed arguments
---@return table|nil context `{ token, owner, repository }`
---@return string|nil reason Why it could not be resolved
local function context(parameters)
  local options = require('agitate.config').options
  local token = options.github_access_token

  if not token then
    return nil, 'undefined GitHub access token'
  end

  local origin_owner, origin_repository = util.origin_repository()
  local owner = parameters['-u'] or origin_owner or options.github_username
  local repository = parameters['-r'] or origin_repository

  if not owner or not repository then
    return nil, 'could not determine which repository to use.' .. '\nPass `-u` and `-r`, or run this inside a repository whose `origin` points at GitHub.'
  end

  return { token = token, owner = owner, repository = repository }
end

---Parses arguments and resolves the context, reporting either failure.
---@param flags string[] The declared flags
---@param optional_parameters table<string>|nil
---@param command string The command name, for the messages
---@param callback fun(context: table, parameters: table<string, string>)
local function prepare(flags, optional_parameters, command, callback)
  local parameters, leftover, incomplete = parse_args(flags, optional_parameters)

  -- Without this, `:AgitateIssueView -n` reports nothing and falls back to
  -- the defaults, acting on a different issue than the one being asked for.
  if #incomplete > 0 then
    return agitate_error.throw(command .. ' -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw(command .. ' -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local resolved, reason = context(parameters)

  if not resolved then
    return agitate_error.throw(command .. ' -- Error: ' .. reason)
  end

  callback(resolved, parameters)
end

---Reads an issue number from a parameter, reporting anything that is not one.
---@param value string|nil
---@param command string
---@return number|nil
local function issue_number(value, command)
  local number = tonumber(value)

  -- Issue numbers are positive integers. `3.14`, `0` and `-1` all survive
  -- `tonumber` and would go on to build a path GitHub cannot answer, so the
  -- mistake is worth naming here rather than as a 404 later.
  if not number or number < 1 or number % 1 ~= 0 then
    agitate_error.throw(command .. ' -- Error: expected a positive issue number, got `' .. tostring(value) .. '`')

    return nil
  end

  return number
end

---Opens the view for one issue, fetching it and its comments.
---@param resolved table The context
---@param number number
local function view(resolved, number)
  github.get_issue(resolved.token, resolved.owner, resolved.repository, number, function(issue_ok, issue)
    if not issue_ok then
      return agitate_error.throw(issue)
    end

    github.list_comments(resolved.token, resolved.owner, resolved.repository, number, function(comments_ok, comments)
      -- The issue itself is worth showing even if the comments could not be
      -- fetched, so a failure here degrades rather than aborts.
      document.open(
        'agitate://issue/' .. resolved.owner .. '/' .. resolved.repository .. '/' .. number,
        document.render(issue, comments_ok and comments or nil)
      )

      if not comments_ok then
        -- The reason matters: expired token, rate limit and network failure
        -- all land here and need different responses from the user.
        vim.notify('Could not load the comments for #' .. number .. '.\n' .. (agitate_error.describe(comments) or 'No reason given.'), vim.log.levels.WARN)
      end
    end)
  end)
end

---Open a new issue
---@param optional_parameters? table<string> `-u` owner and `-r` repository,
---both defaulting to the `origin` remote.
function M.Create(optional_parameters)
  prepare({ '-u', '-r' }, optional_parameters, 'core.issue.Create', function(resolved)
    editor.open({
      name = 'agitate://issue/new',
      help = {
        'First line is the title, the rest is the body.',
        'Write the buffer to submit, `:q!` to abandon.',
      },
    }, function(title, body)
      github.create_issue(resolved.token, resolved.owner, resolved.repository, { title = title, body = body }, function(created_ok, issue)
        if not created_ok then
          return agitate_error.throw(issue)
        end

        vim.notify('Opened #' .. issue.number .. ': ' .. issue.html_url, vim.log.levels.INFO)
      end)
    end)
  end)
end

---List the issues of a repository
---@param optional_parameters? table<string> `-s` state (`open`, `closed` or
---`all`, defaulting to `open`), `-u` owner and `-r` repository.
function M.List(optional_parameters)
  prepare({ '-s', '-u', '-r' }, optional_parameters, 'core.issue.List', function(resolved, parameters)
    local state = parameters['-s'] or 'open'

    if state ~= 'open' and state ~= 'closed' and state ~= 'all' then
      return agitate_error.throw('core.issue.List -- Error: `-s` expects `open`, `closed` or `all`, got `' .. state .. '`')
    end

    github.list_issues(resolved.token, resolved.owner, resolved.repository, state, function(list_ok, issues)
      if not list_ok then
        return agitate_error.throw(issues)
      end

      list.open({
        name = 'agitate://issues/' .. resolved.owner .. '/' .. resolved.repository,
        entries = issues,
        help = {
          '<CR> view   o open in browser   c comment   x close   q quit',
        },
        keymaps = {
          ['<CR>'] = function(entry)
            view(resolved, entry.number)
          end,
          ['o'] = function(entry)
            if not entry.html_url then
              return agitate_error.throw('core.issue.List -- Error: #' .. tostring(entry.number) .. ' has no URL to open.')
            end

            util.open_url(entry.html_url)
          end,
          ['c'] = function(entry)
            M._comment(resolved, entry.number)
          end,
          ['x'] = function(entry)
            M._close(resolved, entry.number)
          end,
        },
      })
    end)
  end)
end

---View a single issue
---@param optional_parameters? table<string> `-n` issue number, `-u` owner, `-r` repository.
function M.View(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.issue.View', function(resolved, parameters)
    local number = issue_number(parameters['-n'], 'core.issue.View')

    if number then
      view(resolved, number)
    end
  end)
end

---Adds a comment to an issue, given an already resolved context.
---@param resolved table
---@param number number
function M._comment(resolved, number)
  editor.open({
    name = 'agitate://issue/' .. number .. '/comment',
    -- `raw` because a comment has no title. Without it the buffer went through
    -- the title split, which trimmed the first line and collapsed the blank
    -- line after it, contradicting the help text below.
    raw = true,
    help = {
      'Write your comment. The first line is not treated specially here.',
      'Write the buffer to submit, `:q!` to abandon.',
    },
  }, function(_, body)
    local text = body

    github.create_comment(resolved.token, resolved.owner, resolved.repository, number, text, function(commented_ok, comment)
      if not commented_ok then
        return agitate_error.throw(comment)
      end

      vim.notify('Commented on #' .. number .. '.', vim.log.levels.INFO)
    end)
  end)
end

---Closes an issue, given an already resolved context.
---@param resolved table
---@param number number
function M._close(resolved, number)
  github.set_issue_state(resolved.token, resolved.owner, resolved.repository, number, 'closed', function(closed_ok, issue)
    if not closed_ok then
      return agitate_error.throw(issue)
    end

    vim.notify('Closed #' .. number .. '.', vim.log.levels.INFO)
  end)
end

---Comment on an issue
---@param optional_parameters? table<string> `-n` issue number, `-u` owner, `-r` repository.
function M.Comment(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.issue.Comment', function(resolved, parameters)
    local number = issue_number(parameters['-n'], 'core.issue.Comment')

    if number then
      M._comment(resolved, number)
    end
  end)
end

---Close an issue
---@param optional_parameters? table<string> `-n` issue number, `-u` owner, `-r` repository.
function M.Close(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.issue.Close', function(resolved, parameters)
    local number = issue_number(parameters['-n'], 'core.issue.Close')

    if number then
      M._close(resolved, number)
    end
  end)
end

---Reopen an issue
---@param optional_parameters? table<string> `-n` issue number, `-u` owner, `-r` repository.
function M.Reopen(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.issue.Reopen', function(resolved, parameters)
    local number = issue_number(parameters['-n'], 'core.issue.Reopen')

    if not number then
      return
    end

    github.set_issue_state(resolved.token, resolved.owner, resolved.repository, number, 'open', function(opened_ok, issue)
      if not opened_ok then
        return agitate_error.throw(issue)
      end

      vim.notify('Reopened #' .. number .. '.', vim.log.levels.INFO)
    end)
  end)
end

return M
