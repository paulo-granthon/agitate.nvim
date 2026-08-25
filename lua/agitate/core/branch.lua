local M = {}

function M.CreateCheckoutAndPush(branch_name)
  if branch_name ~= nil and branch_name ~= '' then
    vim.cmd('G checkout -b ' .. branch_name)
    vim.cmd('G push -u origin ' .. branch_name)
  else
    vim.notify('core.branch.CreateCheckoutAndPush -- Error: no branch name provided', vim.log.levels.ERROR)
  end
end

return M
