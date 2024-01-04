---@class RepositoryConfig
---@field show_status_on_init? boolean Call `:G` after `:AgitateRepoInitGitHub`

---@class Config
---@field github_username? string|nil Your GitHub profile's username
---@field github_access_token? string|nil Your GitHub profile's PAT (Personal Access Token)
---@field repo? RepositoryConfig Options related to the `repository` context
