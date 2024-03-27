---@class GitHubNewRepoSuccessResponse
---@field html_url string The URL of the repository

---@class GitHubGetOrgSuccessResponse
---@field name string The full name of the organization
---@field repos_url string The URL of the organization's repositories

---@class GitHubErrorResponse
---@field errors GitHubError[] Errors during the request

---@class GitHubError
---@field message string Message of the error
