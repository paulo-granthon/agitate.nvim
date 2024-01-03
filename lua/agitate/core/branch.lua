local M = {}

function M.CreateCheckoutAndPush(branch_name)
    if branch_name ~= nil and branch_name ~= '' then
        vim.cmd('G checkout -b ' .. branch_name)
        vim.cmd('G push -u origin ' .. branch_name)
    else
        print('Please provide an argument for the name of the branch')
    end
end

return M
