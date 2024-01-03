local M = {}

-- Function to get the current directory name
function M.get_directory_name()
    return vim.fn.getcwd():match("^.+/(.+)$")
end


-- Function to execute shell commands
function M.execute_command(command)
    local output = vim.fn.systemlist(command)
    for _, line in ipairs(output) do
        print(line)
    end
end

return M
