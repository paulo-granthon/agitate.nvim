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
---@param lines string[] the lines to flatten
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
  -- Through `M.git`, so it reads the buffer's repository rather than whatever
  -- the process working directory happens to be.
  local output, ok = M.git({ 'remote', 'get-url', 'origin' })

  if not ok then
    return nil, nil
  end

  return M.parse_github_remote(output[1])
end

---Percent encodes a string for use as a single URL path segment.
---
---Leaves the unreserved set alone and encodes everything else. GitHub has
---template names such as `C++`, and a name containing `#` or a space would
---otherwise change which endpoint the request reaches rather than failing
---visibly.
---@param segment string
---@return string
function M.encode_path_segment(segment)
  return (segment:gsub('[^%w%-%_%.%~]', function(character)
    return string.format('%%%02X', string.byte(character))
  end))
end

---Returns the directory git commands should run in.
---
---The current buffer's directory, not the process working directory. Fugitive
---resolved the repository from the buffer, so every direct git call has to do
---the same or `:cd` silently changes which repository Agitate acts on. Falls
---back to the working directory for a buffer with no file, which is what the
---scratch buffers are.
---@return string
function M.buffer_directory()
  local buffer_path = vim.api.nvim_buf_get_name(0)

  if buffer_path == '' then
    return vim.fn.getcwd()
  end

  local directory = vim.fn.fnamemodify(buffer_path, ':p:h')

  return vim.fn.isdirectory(directory) == 1 and directory or vim.fn.getcwd()
end

---Runs a git command in the current buffer's repository.
---
---Merges stdout and stderr, because git reports almost every failure on
---stderr and a caller that only sees stdout reports a failure with no reason.
---@param argv string[] The git command, without the leading `git`
---@param directory string|nil Where to run, defaulting to the buffer's directory
---@return string[] output
---@return boolean ok
function M.git(argv, directory)
  local command = { 'git', '-C', directory or M.buffer_directory() }
  vim.list_extend(command, argv)

  local completed = vim.system(command, { text = true }):wait()

  local lines = {}
  for _, stream in ipairs({ completed.stdout, completed.stderr }) do
    for _, line in ipairs(vim.split(stream or '', '\n')) do
      if line ~= '' then
        lines[#lines + 1] = line
      end
    end
  end

  return lines, completed.code == 0
end

---Opens a URL in the user's browser.
---@param url string|nil
---@return boolean ok
---@return string|nil reason
function M.open_url(url)
  -- Validated because the usual caller passes a field straight off a GitHub
  -- payload, so a response without `html_url` would reach `vim.ui.open` as nil
  -- and raise from inside the UI layer instead of saying what was missing.
  if type(url) ~= 'string' or not url:match('%S') then
    return false, 'no URL to open'
  end

  -- `vim.ui.open` raises when it cannot find an opener, which depends on the
  -- platform and the user's configuration, so the caller gets a reason rather
  -- than a traceback from inside the UI layer.
  local opened, err = pcall(vim.ui.open, url)

  if not opened then
    return false, tostring(err)
  end

  return true
end

return M
