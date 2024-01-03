local M = {}

function M.setup()
    require('agitate.api.branch').setup()
    require('agitate.api.repo').setup()
end

return M
