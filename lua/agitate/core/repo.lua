local M = {}

local ok, error = pcall(require, 'agitate.error')
if not ok then
    return vim.api.nvim_err_writeln(require('agitate.const.error').import)
end

local util_ok, util_or_err = pcall(require, 'agitate.util')
if not util_ok then return error.throw(util_or_err) end

local github_ok, github_or_err = pcall(require, 'agitate.service.github')
if not github_ok then return error.throw(github_or_err) end

local util = util_or_err
local github = github_or_err

---Create a new repository on GitHub
---@param optional_repo_name? string The name of the repository to create. Default: current directory
function M.CreateGitHubCurl(optional_repo_name)
    local options = require('agitate.config').options

    local new_github_repository_name = optional_repo_name or util.get_directory_name()
    local github_username = options.github_username
    local github_access_token = options.github_access_token

    if not github_username or not github_access_token then
        return error('Agitate | CreateGitHubCurl | Error - Undefined GitHub Username or Access Token')
    end

    local ok, repository_created_response = github_service.post_new_repo(
        github_access_token,
        new_github_repository_name
    )

    if not ok then
        print(repository_created_response)
    end

    if repository_created_response.errors then
        return vim.api.nvim_err_writeln(
            'Agitate | CreateGitHubCurl | Error:' ..
            '\nFailed to create repository at ' ..
            ' `https://github.com/' .. github_username .. '/' .. new_github_repository_name .. '/`' ..
            '\nReason: `' .. repository_created_response.errors[1].message .. '`'
        )
    end

    print(
        'Created remote GitHub repository at ' .. repository_created_response.html_url ..
        '\nYou can initialize the current directory to this remote origin with `:AgitateRepoInitGitHub ' ..
        new_github_repository_name .. '`'
    )
end

---Initialize a new repository and push to GitHub
---@param optional_repo_name? string The name of the repository to use as remote origin. Default: current directory
function M.InitGitHub(optional_repo_name)
    local options = require('agitate.config').options

    local github_repository_name = optional_repo_name or util.get_directory_name()
    local github_username = options.github_username

    vim.pretty_print(util.execute_command('echo "# ' .. github_repository_name .. '" >> README.md'))
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
