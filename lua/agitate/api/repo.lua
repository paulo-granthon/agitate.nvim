local M = {}

function M.setup()
    vim.api.nvim_create_user_command(
        'AgitateRepoCreateGitHub',
        function(opts)
            require('agitate.core.repo').CreateGitHubCurl(
                opts.fargs and opts.fargs[1] or nil
            )
        end, {
            nargs = '?',
            desc = 'Creates a new repository at \'github.com/<github_username>/<argument or current_directory>/\'',
        }
    )

    vim.api.nvim_create_user_command(
        'AgitateRepoInitGitHub',
        function(opts)
            require('agitate.core.repo').InitGitHub(
                opts.fargs and opts.fargs[1] or nil
            )
        end, {
            nargs = '?',
            desc = 'Initialize the current directory as a repository at \'github.com/<github_username>/<argument or current_directory>/\'',
        }
    )
end

return M
