---@class GitHubNewRepoSuccessResponse
---@field html_url string The URL of the repository
---@field name string The name of the repository

---The `is_private` name avoids `private`, which LuaLS reads as a visibility
---keyword in a `@field` annotation rather than as a field name.
---@class CreateRepositoryOptions
---@field name string The name of the repository to create
---@field is_private boolean Whether the repository should be private
---@field path string The API path to post to, either `user` or `orgs/<name>`

---@class GitHubErrorResponse
---@field message string The top level description of the failure
---@field errors GitHubError[] The field level errors, when GitHub supplies them

---@class GitHubError
---@field message string Message of the error
