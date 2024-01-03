local M = {}

function M.setup()
    vim.api.nvim_create_user_command(
        'AgitateBranchCreateCheckoutAndPush',
        function(opts)
            require('agitate.core.branch').CreateCheckoutAndPush(opts.fargs[1])
        end, {
            nargs = 1,
            desc = 'Create a new branch, `checkout` to it then `push` it to remote',
        }
    )
end

return M
