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

local MERGE_METHODS = { merge = true, squash = true, rebase = true }

---States GitHub reports that mean a merge would not go through.
---
---`clean` and `has_hooks` are mergeable. `unstable` means required checks are
---failing but the merge is still permitted, which is a judgement call rather
---than a blocker, so it asks rather than refuses. Everything here is a refusal.
local BLOCKED_STATES = {
  dirty = 'it has conflicts',
  blocked = 'a required review or check is missing',
  behind = 'the branch is behind its base and the repository requires it to be up to date',
  draft = 'it is still a draft',
}

---Resolves the repository and token every pull request command needs.
---@param parameters table<string, string>
---@return table|nil context
---@return string|nil reason
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
---@param flags string[]
---@param optional_parameters table<string>|nil
---@param command string
---@param callback fun(context: table, parameters: table<string, string>)
local function prepare(flags, optional_parameters, command, callback)
  local parameters, leftover, incomplete = parse_args(flags, optional_parameters)

  -- Without this, `:AgitatePrMerge -n` reports nothing and falls back to the
  -- defaults, which for a merge means acting on a pull request nobody named.
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

---Reads a pull request number, reporting anything that is not one.
---@param value string|nil
---@param command string
---@return number|nil
local function pull_number(value, command)
  local number = tonumber(value)

  -- Pull request numbers are positive integers. `3.14`, `0` and `-1` all
  -- survive `tonumber` and would build a path GitHub cannot answer.
  if not number or number < 1 or number % 1 ~= 0 then
    agitate_error.throw(command .. ' -- Error: expected a positive pull request number, got `' .. tostring(value) .. '`')

    return nil
  end

  return number
end

---Decides whether a pull request can be merged, and what to warn about.
---
---Kept pure so the rules can be tested without a repository or a network. The
---distinction that matters: a state GitHub reports as blocked is a refusal,
---while failing checks on an otherwise mergeable branch is the user's call.
---@param pull table The pull request, as GitHub returns it
---@return table decision `{ allowed = boolean, reason = string|nil, warning = string|nil }`
function M._plan_merge(pull)
  if pull.merged then
    return { allowed = false, reason = 'it is already merged' }
  end

  if pull.state ~= 'open' then
    return { allowed = false, reason = 'it is ' .. tostring(pull.state) }
  end

  local blocked = BLOCKED_STATES[pull.mergeable_state]

  if blocked then
    return { allowed = false, reason = blocked }
  end

  -- `mergeable` is nil while GitHub is still computing it. Merging on an
  -- unknown is how a surprise conflict gets forced through.
  if pull.mergeable == false then
    return { allowed = false, reason = 'GitHub reports it as not mergeable' }
  end

  if pull.mergeable == nil then
    return { allowed = false, reason = 'GitHub has not finished checking whether it can be merged, try again shortly' }
  end

  if pull.mergeable_state == 'unstable' then
    return { allowed = true, warning = 'Required checks are failing or still running.' }
  end

  return { allowed = true }
end

---Opens the view for one pull request.
---@param resolved table
---@param number number
local function view(resolved, number)
  github.get_pull_request(resolved.token, resolved.owner, resolved.repository, number, function(pull_ok, pull)
    if not pull_ok then
      return agitate_error.throw(pull)
    end

    github.list_comments(resolved.token, resolved.owner, resolved.repository, number, function(comments_ok, comments)
      document.open(
        'agitate://pr/' .. resolved.owner .. '/' .. resolved.repository .. '/' .. number,
        document.render(pull, comments_ok and comments or nil, {
          '- Base: ' .. tostring((pull.base or {}).ref or 'unknown'),
          '- Head: ' .. tostring((pull.head or {}).ref or 'unknown'),
        })
      )

      if not comments_ok then
        vim.notify('Could not load the comments for #' .. number .. '.', vim.log.levels.WARN)
      end
    end)
  end)
end

---Open a new pull request
---@param optional_parameters? table<string> `-B` base branch, `-H` head branch,
---`-u` owner and `-r` repository. Head defaults to the current branch and base
---to the repository's default branch.
function M.Create(optional_parameters)
  prepare({ '-B', '-H', '-u', '-r' }, optional_parameters, 'core.pr.Create', function(resolved, parameters)
    local head = parameters['-H'] or util.current_branch()

    if not head then
      return agitate_error.throw('core.pr.Create -- Error: could not determine the branch to open from. Pass `-H`.')
    end

    local function compose(base)
      if head == base then
        return agitate_error.throw('core.pr.Create -- Error: the head and base branches are both `' .. base .. '`.')
      end

      editor.open({
        -- Repository qualified so two repositories do not collide on one
        -- buffer name.
        name = 'agitate://pr/' .. resolved.owner .. '/' .. resolved.repository .. '/new',
        help = {
          head .. ' into ' .. base,
          'First line is the title, the rest is the body.',
          'Write the buffer to submit, `:q!` to abandon.',
        },
      }, function(title, body)
        github.create_pull_request(resolved.token, resolved.owner, resolved.repository, {
          title = title,
          body = body,
          head = head,
          base = base,
        }, function(created_ok, pull)
          if not created_ok then
            return agitate_error.throw(pull)
          end

          -- Both are concatenated into the message, so a payload missing
          -- either would raise while announcing the success.
          if not pull.number or not pull.html_url then
            return agitate_error.throw('core.pr.Create -- Error: GitHub reported success but returned no `number` or `html_url`.')
          end

          vim.notify('Opened #' .. pull.number .. ': ' .. pull.html_url, vim.log.levels.INFO)
        end)
      end)
    end

    if parameters['-B'] then
      return compose(parameters['-B'])
    end

    -- The default branch is a property of the repository, not something to
    -- guess at. `main` and `master` are both still common.
    github.get_repository(resolved.token, resolved.owner, resolved.repository, function(repository_ok, repository)
      if not repository_ok then
        return agitate_error.throw(repository)
      end

      -- `compose` builds strings from this, so a payload without it would
      -- error while formatting rather than say what went wrong.
      if not repository.default_branch then
        return agitate_error.throw(
          'core.pr.Create -- Error: GitHub returned no default branch for `'
            .. resolved.owner
            .. '/'
            .. resolved.repository
            .. '`. Pass `-B` to name the base branch explicitly.'
        )
      end

      compose(repository.default_branch)
    end)
  end)
end

---List the pull requests of a repository
---@param optional_parameters? table<string> `-s` state, `-u` owner, `-r` repository.
function M.List(optional_parameters)
  prepare({ '-s', '-u', '-r' }, optional_parameters, 'core.pr.List', function(resolved, parameters)
    local state = parameters['-s'] or 'open'

    if state ~= 'open' and state ~= 'closed' and state ~= 'all' then
      return agitate_error.throw('core.pr.List -- Error: `-s` expects `open`, `closed` or `all`, got `' .. state .. '`')
    end

    github.list_pull_requests(resolved.token, resolved.owner, resolved.repository, state, function(list_ok, pulls)
      if not list_ok then
        return agitate_error.throw(pulls)
      end

      list.open({
        name = 'agitate://prs/' .. resolved.owner .. '/' .. resolved.repository,
        entries = pulls,
        help = {
          '<CR> view   o open in browser   c comment   m merge   q quit',
        },
        keymaps = {
          ['<CR>'] = function(entry)
            view(resolved, entry.number)
          end,
          ['o'] = function(entry)
            if not entry.html_url then
              return agitate_error.throw('core.pr.List -- Error: #' .. tostring(entry.number) .. ' has no URL to open.')
            end

            util.open_url(entry.html_url)
          end,
          ['c'] = function(entry)
            M._comment(resolved, entry.number)
          end,
          ['m'] = function(entry)
            M._merge(resolved, entry.number, 'merge')
          end,
        },
      })
    end)
  end)
end

---View a single pull request
---@param optional_parameters? table<string> `-n` number, `-u` owner, `-r` repository.
function M.View(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.pr.View', function(resolved, parameters)
    local number = pull_number(parameters['-n'], 'core.pr.View')

    if number then
      view(resolved, number)
    end
  end)
end

---Adds a comment to a pull request, given an already resolved context.
---@param resolved table
---@param number number
function M._comment(resolved, number)
  editor.open({
    name = 'agitate://pr/' .. resolved.owner .. '/' .. resolved.repository .. '/' .. number .. '/comment',
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

---Merges a pull request, given an already resolved context.
---
---Fetches it first, because the list endpoint does not compute `mergeable`,
---and refuses rather than letting GitHub reject the request, so the reason is
---reported before anything is sent.
---@param resolved table
---@param number number
---@param method string
function M._merge(resolved, number, method)
  github.get_pull_request(resolved.token, resolved.owner, resolved.repository, number, function(pull_ok, pull)
    if not pull_ok then
      return agitate_error.throw(pull)
    end

    local decision = M._plan_merge(pull)

    if not decision.allowed then
      return agitate_error.throw('core.pr.Merge -- Error: cannot merge #' .. number .. ' because ' .. decision.reason .. '.')
    end

    local prompt = 'Merge #'
      .. number
      .. ' ('
      .. tostring(pull.title)
      .. ')'
      .. '\n'
      .. tostring((pull.head or {}).ref)
      .. ' into '
      .. tostring((pull.base or {}).ref)
      .. ' using the '
      .. method
      .. ' method?'

    if decision.warning then
      prompt = prompt .. '\n\n' .. decision.warning
    end

    if vim.fn.confirm(prompt, '&Merge\n&Cancel', 2, 'Question') ~= 1 then
      return vim.notify('Merge cancelled.', vim.log.levels.INFO)
    end

    github.merge_pull_request(resolved.token, resolved.owner, resolved.repository, number, method, function(merged_ok, result)
      if not merged_ok then
        return agitate_error.throw(result)
      end

      vim.notify('Merged #' .. number .. '. ' .. tostring(result.message or ''), vim.log.levels.INFO)
    end)
  end)
end

---Comment on a pull request
---@param optional_parameters? table<string> `-n` number, `-u` owner, `-r` repository.
function M.Comment(optional_parameters)
  prepare({ '-n', '-u', '-r' }, optional_parameters, 'core.pr.Comment', function(resolved, parameters)
    local number = pull_number(parameters['-n'], 'core.pr.Comment')

    if number then
      M._comment(resolved, number)
    end
  end)
end

---Merge a pull request
---@param optional_parameters? table<string> `-n` number, `-m` merge method
---(`merge`, `squash` or `rebase`, defaulting to `merge`), `-u` owner, `-r` repository.
function M.Merge(optional_parameters)
  prepare({ '-n', '-m', '-u', '-r' }, optional_parameters, 'core.pr.Merge', function(resolved, parameters)
    local number = pull_number(parameters['-n'], 'core.pr.Merge')

    if not number then
      return
    end

    local method = parameters['-m'] or 'merge'

    if not MERGE_METHODS[method] then
      return agitate_error.throw('core.pr.Merge -- Error: `-m` expects `merge`, `squash` or `rebase`, got `' .. method .. '`')
    end

    M._merge(resolved, number, method)
  end)
end

return M
