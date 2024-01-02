local config = require('agitate.config')
local repo = require('agitate.repo')

local M = {}

---@param opts Config|nil
function M.load(opts)
    print('load monstro')
    if opts then
        config.extend(opts)
    end
end

function M.setup()
    print('setup monstro')
    config.setup()
    repo.setup()
end

return M
