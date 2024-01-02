local M = {}

local options = require('agitate.config').options
local util = require('agitate.util')

-- Function to initialize a new repository and push to GitHub
M.AgitateRepositoryInitGitHub = function ()

    local directory_name = util.get_directory_name()
    local github_username = options.github_username

    print(github_username)

    util.execute_command('echo "# ' .. directory_name .. '" >> README.md')
    util.execute_command('git init')
    util.execute_command('git add README.md')
    util.execute_command('git commit -m "first commit"')
    util.execute_command('git branch -M main')
    util.execute_command('git remote add origin https://github.com/' .. github_username .. '/' .. directory_name .. '.git')
    util.execute_command('git push -u origin main')

    -- Open fugitive status window
    vim.cmd('G')
end

return M
