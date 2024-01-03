local M = {}

---@class Config
local defaults = {
    github_username = nil,
    repo = {
        show_status_on_init = false,
    },
}

---@type Config
M.options = {}

---@param options Config|nil
function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
    require('agitate.core').setup()
end

---@param options Config|nil
function M.extend(options)
    M.options = vim.tbl_deep_extend("force", {}, M.options or defaults, options or {})
end

M.setup()

return M
