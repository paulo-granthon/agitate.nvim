---@class Config
---@field github_username? string|nil Your GitHub profile's username
---@field github_access_token? string|nil Your GitHub profile's PAT (Personal Access Token)
---@field repo? RepositoryConfig Options related to the `repository` context
---@field file? FileConfig Options related to the `file` context

---@class RepositoryConfig
---@field init? RepositoryInitConfig Options for the local initialization of a repository

---@class RepositoryInitConfig
---@field show_status? boolean|nil Call `:G` after `:AgitateRepoInit`
---@field first_commit_message? string|nil The message to use for the first commit

---@class FileConfig
---@field license? LicenseConfig Options for generating a LICENSE

---@class LicenseConfig
---@field author? string|nil The copyright holder written into a generated LICENSE
