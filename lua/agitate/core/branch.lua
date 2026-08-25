local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

local parse_args = require('agitate.parse_args')

function M.CreateCheckoutAndPush(branch_name)
  if branch_name ~= nil and branch_name ~= '' then
    vim.cmd('G checkout -b ' .. branch_name)
    vim.cmd('G push -u origin ' .. branch_name)
  else
    vim.notify('core.branch.CreateCheckoutAndPush -- Error: no branch name provided', vim.log.levels.ERROR)
  end
end

---Runs a git command directly and reports whether it succeeded.
---
---Read only queries go through git rather than fugitive because the answer is
---needed as a value here, not as output in a window.
---@param argv string[] The git command, without the leading `git`
---@return string[] output
---@return boolean ok
local function git(argv)
  local command = { 'git' }
  vim.list_extend(command, argv)

  local output = vim.fn.systemlist(command)

  return output, vim.v.shell_error == 0
end

---Returns the name of the currently checked out branch, or nil in a detached
---HEAD or outside a repository.
---@return string|nil
function M.current_branch()
  local output, git_ok = git({ 'rev-parse', '--abbrev-ref', 'HEAD' })

  if not git_ok or not output[1] or output[1] == '' or output[1] == 'HEAD' then
    return nil
  end

  return output[1]
end

---Reports whether the branch has a counterpart under the given remote.
---
---Checks the local remote tracking ref rather than asking the remote, so this
---stays fast and works offline. A remote branch created elsewhere and never
---fetched will read as absent, which only means the remote delete is skipped.
---@param remote string
---@param branch string
---@return boolean
function M.exists_on_remote(remote, branch)
  local _, git_ok = git({ 'rev-parse', '--verify', '--quiet', 'refs/remotes/' .. remote .. '/' .. branch })

  return git_ok
end

---Decides what deleting a branch should do, without doing any of it.
---
---Separated from the command so the rules can be tested without a repository:
---everything below is a pure function of its arguments.
---@param branch string|nil The branch the user asked for
---@param current string|nil The currently checked out branch
---@param has_remote boolean Whether the branch exists on the remote
---@return table Plan `{ ok = false, reason = string }` or `{ ok = true, branch = string, delete_remote = boolean }`
function M.plan_delete(branch, current, has_remote)
  if not branch or branch == '' then
    if not current then
      return { ok = false, reason = 'no branch name given, and the current branch could not be determined' }
    end

    branch = current
  end

  -- git refuses to delete the branch that is checked out, and doing it for the
  -- user by switching away would be a surprising side effect of a delete.
  if branch == current then
    return {
      ok = false,
      reason = '`' .. branch .. '` is the current branch. Check out another branch first, then delete it.',
    }
  end

  return { ok = true, branch = branch, delete_remote = has_remote }
end

---Builds the text of the confirmation prompt.
---@param branch string
---@param delete_remote boolean
---@param remote string
---@return string
function M.confirm_prompt(branch, delete_remote, remote)
  if delete_remote then
    return 'Delete branch `' .. branch .. '` locally and from `' .. remote .. '`?'
  end

  return 'Delete branch `' .. branch .. '` locally? It has no counterpart on `' .. remote .. '`.'
end

---Delete a branch locally and, when it has one, its remote counterpart
---@param optional_parameters? table<string> Parameters can be passed in order or explicitly
---with their corresponding flags:
---  -b: The name of the branch to delete. Defaults to the current branch.
---  -r: The remote to delete it from. Defaults to `origin`.
function M.Delete(optional_parameters)
  local parameters, leftover = parse_args({ '-b', '-r' }, optional_parameters)

  if #leftover > 0 then
    return agitate_error.throw('core.branch.Delete -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local remote = parameters['-r'] or 'origin'
  local requested = parameters['-b']
  local current = M.current_branch()

  local plan = M.plan_delete(requested, current, false)

  if not plan.ok then
    return agitate_error.throw('core.branch.Delete -- Error: ' .. plan.reason)
  end

  plan.delete_remote = M.exists_on_remote(remote, plan.branch)

  -- Deleting a branch discards work that may not exist anywhere else, so the
  -- user confirms before anything is run. `-d` is the safe form and refuses to
  -- drop unmerged commits; forcing is a separate, explicit choice.
  local choice = vim.fn.confirm(M.confirm_prompt(plan.branch, plan.delete_remote, remote), '&Delete\n&Force delete\n&Cancel', 3, 'Question')

  if choice ~= 1 and choice ~= 2 then
    return vim.notify('Branch deletion cancelled.', vim.log.levels.INFO)
  end

  vim.cmd('G branch ' .. (choice == 2 and '-D ' or '-d ') .. plan.branch)

  if plan.delete_remote then
    vim.cmd('G push ' .. remote .. ' --delete ' .. plan.branch)
  end
end

return M
