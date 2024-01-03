local M = {}

local util = require('agitate.util')

---Create a new repository on GitHub
---@param optional_repo_name? string The name of the repository to create. Default: current directory
function M.CreateGitHubCurl(optional_repo_name)
    local options = require('agitate.config').options

    local new_github_repository_name = optional_repo_name or util.get_directory_name()
    local github_username = options.github_username
    local github_access_token = options.github_access_token

    if not github_username or not github_access_token then
        return error('Agitate | CreateGitHub | Error - Undefined GitHub Username or Access Token')
    end

    util.execute_command(
        'curl' ..
        ' -H ' .. '"Authorization: token ' .. github_access_token .. '"' ..
        ' https://api.github.com/user/repos' ..
        ' -d ' .. [['{"name":"]] .. new_github_repository_name .. [["}']]
    )
end

---Initialize a new repository and push to GitHub
---@param optional_repo_name? string The name of the repository to use as remote origin. Default: current directory
function M.InitGitHub(optional_repo_name)
    local options = require('agitate.config').options

    local github_repository_name = optional_repo_name or util.get_directory_name()
    local github_username = options.github_username

    util.execute_command('echo "# ' .. github_repository_name .. '" >> README.md')
    vim.cmd('G init')
    vim.cmd('G add README.md')
    vim.cmd('G commit -m "first commit"')
    vim.cmd('G branch -M main')
    vim.cmd('G remote add origin https://github.com/' .. github_username .. '/' .. github_repository_name .. '.git')
    vim.cmd('G push -u origin main')

    -- Open fugitive status window
    if options.repo.show_status_on_init then
        vim.cmd('G')
    end
end

return M
