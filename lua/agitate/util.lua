local M = {}

-- Function to get the current directory name
function M.get_directory_name()
  return vim.fn.getcwd():match('^.+/(.+)$')
end

-- Function to execute shell commands
function M.execute_command(command)
  return vim.fn.systemlist(command)
end

---@class FlattenTableOptions
---@field skip? number The number of lines to skip before constructing the table

---Flattens a table of strings into a single space separated string
---@param lines table the table to flatten
---@param opts? FlattenTableOptions the optional options table
---@return string Flattened The joined lines
function M.flatten_table(lines, opts)
  local skip = opts and opts.skip or 0
  local parts = {}

  for index = skip + 1, #lines do
    parts[#parts + 1] = lines[index]
  end

  return table.concat(parts, ' ')
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
  return false, nil
end

---Builds a github html url from the provided username and repository name
---@param username string The GitHub username or organization
---@param repository_name string The name of the repository
---@return string The GitHub repository html url
function M.build_github_html_url(username, repository_name)
  return 'https://github.com/' .. username .. '/' .. repository_name
end

---Extracts the owner and repository name from a GitHub remote URL.
---
---Recognises the https URL and the scp style ssh remote. `git remote get-url`
---can return other shapes too, so an unrecognised one resolves to nil rather
---than a guess. The trailing `.git` is optional, because it is optional in
---what git accepts.
---@param url string|nil A git remote URL
---@return string|nil owner
---@return string|nil repository
function M.parse_github_remote(url)
  if type(url) ~= 'string' then
    return nil, nil
  end

  local owner, repository = url:match('^https://github%.com/([^/]+)/([^/]+)$')

  if not owner then
    owner, repository = url:match('^git@github%.com:([^/]+)/([^/]+)$')
  end

  -- `git remote get-url` also returns the full ssh URL form, optionally with a
  -- port. Without it an `ssh://` origin resolved to nil and every command that
  -- defaults from the remote asked for `-u` and `-r` instead.
  if not owner then
    -- Two exact alternatives rather than one loose pattern. `:?%d*` made the
    -- colon optional as well as the digits, so `github.com443/owner/repo` was
    -- accepted as GitHub. Lua patterns have no optional group, so the port
    -- form is spelled out separately.
    owner, repository = url:match('^ssh://git@github%.com/([^/]+)/([^/]+)$')

    if not owner then
      owner, repository = url:match('^ssh://git@github%.com:%d+/([^/]+)/([^/]+)$')
    end
  end

  if not owner then
    return nil, nil
  end

  return owner, (repository:gsub('%.git$', ''))
end

---Reads the owner and repository from the `origin` remote of the current
---repository, so commands can default to the checkout the user is sitting in.
---@return string|nil owner
---@return string|nil repository
function M.origin_repository()
  local output = vim.fn.systemlist({ 'git', 'remote', 'get-url', 'origin' })

  if vim.v.shell_error ~= 0 then
    return nil, nil
  end

  return M.parse_github_remote(output[1])
end

---Opens a URL in the user's browser.
---@param url string
function M.open_url(url)
  vim.ui.open(url)
end

return M
