local M = {}

-- Function to get the current directory name
M.get_directory_name = function()
    return vim.fn.getcwd():match("^.+/(.+)$")
end


-- Function to execute shell commands
M.execute_command = function(command)
    local output = vim.fn.systemlist(command)
    for _, line in ipairs(output) do
        print(line)
    end
end

return M
