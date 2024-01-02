local config = require('agitate.config')

local M = {}

---@param opts Config|nil
function M.load(opts)
    if opts then
        config.extend(opts)
    end
end

M.setup = config.setup

return M
