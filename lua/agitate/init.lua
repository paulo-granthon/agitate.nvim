local config = require('agitate.config')
local repo = require('agitate.repo')

local M = {}

---@param opts Config|nil
function M.load(opts)
    if opts then
        require("agitate.config").extend(opts)
    end
    repo.setup()
end

M.setup = config.setup

return M
