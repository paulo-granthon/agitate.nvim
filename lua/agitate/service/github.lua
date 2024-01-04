local M = {}

local util = require('agitate.util')
require('types.github')

---Creates a new remote repository through the GitHub API
---@param access_token string Your GitHub PAT (Personal Access Token)
---@param repository string Name of the repository to be created
---@return boolean Ok If proccess was executed successfully
---@return GitHubSuccessResponse|GitHubErrorResponse|string Response
---Response properly formatted for the rest of `agitated.nvim`
function M.post_new_repo(access_token, repository)
    -- Execute curl to create the repository through the GitHub api
    local raw_github_response = util.execute_command(
        'curl' ..
        ' -H ' .. '"Authorization: token ' .. access_token .. '"' ..
        ' https://api.github.com/user/repos' ..
        ' -d ' .. [['{"name":"]] .. repository .. [["}']]
    )

    -- Flatten the table response to string
    local flattened_github_response = util.flatten_table(
        raw_github_response
    )

    -- Trim any noise left of the first `{` or right of the last `}`
    local ok, gsubbed_github_response = util.json_lr_trim(flattened_github_response)
    if not ok then return ok, 'Unhandled error at `service.github.post_new_repo`' end

    -- Return the processed response as a lua table
    return true, vim.json.decode(gsubbed_github_response)
end

return M
