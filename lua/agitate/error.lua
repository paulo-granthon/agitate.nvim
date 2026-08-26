local M = {}

local types_ok, _ = pcall(require, 'agitate.types.error')
if not types_ok then
  local message = require('agitate.const.error').err_types
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

---@param location string Where the error happens
---@return AgitateError Error
function M.unhandled(location)
  return {
    message = 'Unhandled error at `' .. location .. '`',
  }
end

---Resolves any accepted error shape into a printable message.
---
---Returns `nil` when the value carries no message at all, so callers can
---substitute a fallback themselves instead of handing the value back to
---`throw`, which is what used to spin the stack.
---@param err AgitateError|table|string|nil The error to describe
---@return string|nil Message The resolved message, or `nil` if there is none
function M.describe(err)
  if type(err) == 'string' then
    return err
  end

  if type(err) ~= 'table' then
    return nil
  end

  if type(err.message) == 'string' then
    return err.message
  end

  local messages = {}
  for _, value in ipairs(err) do
    local message = M.describe(value)
    if message then
      messages[#messages + 1] = message
    end
  end

  if #messages == 0 then
    return nil
  end

  return table.concat(messages, '\n')
end

---Reports the given error to the user, ending the current execution of agitate.nvim
---@param err AgitateError|table|string The error to throw
function M.throw(err)
  local message = M.describe(err) or M.unhandled('agitate.error.throw').message

  vim.notify('There was an error during execution of agitate.nvim:\n' .. message, vim.log.levels.ERROR)
end

return M
