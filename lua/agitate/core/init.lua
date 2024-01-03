local M = {}

function M.setup()
    require('agitate.core.repo').setup()
    require('agitate.core.branch').setup()
end

return M
