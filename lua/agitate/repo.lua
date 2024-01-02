local M = {}

local util = require('agitate.util')

-- Function to initialize a new repository and push to GitHub
M.InitGitHub = function ()

    local options = require('agitate.config').options

    local directory_name = util.get_directory_name()
    local github_username = options.github_username

    util.execute_command('echo "# ' .. directory_name .. '" >> README.md')
    vim.cmd('G init')
    vim.cmd('G add README.md')
    vim.cmd('G commit -m "first commit"')
    vim.cmd('G branch -M main')
    vim.cmd('G remote add origin https://github.com/' .. github_username .. '/' .. directory_name .. '.git')
    vim.cmd('G push -u origin main')

    -- Open fugitive status window
    if options.repo.show_status_on_init then
        vim.cmd('G')
    end
end

-- Create vim commands
M.setup = function()
    vim.api.nvim_create_user_command('AgitateRepoInitGitHub', function()
        require('agitate.repo').InitGitHub()
    end, {
        desc = 'Initializes the current directory as a repository at \'github.com/github_username/current_directory\'',
    })

    print('user_command was definitely created')
end

return M
