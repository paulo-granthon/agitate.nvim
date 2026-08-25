local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  return vim.notify(require('agitate.const.error').import, vim.log.levels.ERROR)
end

---Registers one file command, deferring the `core.file` require until it runs.
---@param name string The command name
---@param method string The `core.file` function to call
---@param desc string The command description
local function command(name, method, desc)
  vim.api.nvim_create_user_command(name, function(opts)
    local file_ok, file_or_err = pcall(require, 'agitate.core.file')
    if not file_ok then
      return agitate_error.throw(file_or_err)
    end

    file_or_err[method](opts.fargs)
  end, {
    nargs = '*',
    desc = desc,
  })
end

function M.setup()
  command('AgitateFileGitignore', 'Gitignore', 'Add a `.gitignore` from a GitHub template')
  command('AgitateFileLicense', 'License', 'Add a `LICENSE` from a GitHub template')
  command('AgitateFileFunding', 'Funding', 'Add a `.github/FUNDING.yml`')
end

return M
