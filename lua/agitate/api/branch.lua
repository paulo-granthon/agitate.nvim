local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
  return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

function M.setup()
  vim.api.nvim_create_user_command('AgitateBranchCreateCheckoutAndPush', function(opts)
    local branch_ok, branch_or_err = pcall(require, 'agitate.core.branch')
    if not branch_ok then
      return error.throw(branch_or_err)
    end

    branch_or_err.CreateCheckoutAndPush(opts.fargs[1])
  end, {
    nargs = 1,
    desc = 'Create a new branch, `checkout` to it then `push` it to remote',
  })
end

return M
