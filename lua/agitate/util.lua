local M = {}

-- Function to get the current directory name
function M.get_directory_name()
    return vim.fn.getcwd():match("^.+/(.+)$")
end

-- Function to execute shell commands
function M.execute_command(command)
    return vim.fn.systemlist(command)
end

---@class FlattenTableOptions
---@field skip? number The number of lines to skip before constructing the table

---Flattens a table of String into a single String
---@param table table the table to flatten
---@param opts? FlattenTableOptions the optional options table
function M.flatten_table(table, opts)
    local result = ''
    local skip = opts and opts.skip or 0
    for _, line in ipairs(table) do
        if skip > 0 then
            skip = skip - 1
            goto continue
        end
        result = result .. line
        ::continue::
    end
    return result
end

return M
