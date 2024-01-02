local config = require('agitate.config')
local repo = require('agitate.repo')

local M = {}

---@param opts Config|nil
function M.load(opts)
    if opts then
        config.extend(opts)
    end
end

function M.setup()
    config.setup()
    repo.setup()
end

return M
