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

---Removes any characters outside of the `json` object in the provided string
---@param input_string string String containing a `json` object
---@return boolean Ok If proccess was executed successfully
---@return string|nil Json Trimmed `json` string if found
function M.json_lr_trim(input_string)
    -- Find the position of the first '{' and the last '}' in the string
    local start_pos = input_string:find('{')
    local end_pos = input_string:reverse():find('}')

    -- If '{' and '}' are found, extract the substring between them
    if start_pos and end_pos then
        end_pos = #input_string - end_pos + 1
        return true, input_string:sub(start_pos, end_pos)
    end

    -- no `json` found
    return false
end

return M
