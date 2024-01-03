local M = {}

function M.CreateCheckoutAndPush(branch_name)
    if branch_name ~= nil and branch_name ~= '' then
        vim.cmd('G checkout -b ' .. branch_name)
        vim.cmd('G push -u origin ' .. branch_name)
    else
       print('Please provide an argument for the name of the branch')
    end
end

-- Create vim commands
function M.setup()
    vim.api.nvim_create_user_command('AgitateBranchCreateCheckoutAndPush', function(opts)
        require('agitate.core.branch').CreateCheckoutAndPush(opts.fargs[1])
    end, {
        nargs = 1,
        desc = 'Create a new branch, `checkout` to it then `push` it to remote',
    })
end

return M
