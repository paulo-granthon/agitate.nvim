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

---Builds the git remote URL for a repository.
---
---`https` matches what the GitHub web UI offers by default. `ssh` produces the
---`git@github.com:owner/repo.git` form, which is what a user with keys
---configured needs; without it they would have to rewrite the remote by hand
---after every `Init`.
---@param username string The GitHub username or organization
---@param repository_name string The name of the repository
---@param protocol? string Either `https` or `ssh`, defaulting to `https`
---@return string The git remote URL
function M.build_github_remote_url(username, repository_name, protocol)
  if protocol == 'ssh' then
    return 'git@github.com:' .. username .. '/' .. repository_name .. '.git'
  end

  -- Only nil means "use the default". Treating every unrecognised value as
  -- https would turn a typo into a silently wrong remote. `core.repo.Init`
  -- validates before calling, so this guards the helper itself rather than
  -- that one path.
  if protocol ~= nil and protocol ~= 'https' then
    error('util.build_github_remote_url -- Error: protocol expects `https` or `ssh`, got `' .. tostring(protocol) .. '`', 0)
  end

  return M.build_github_html_url(username, repository_name) .. '.git'
end

---Builds a github html url from the provided username and repository name
---@param username string The GitHub username or organization
---@param repository_name string The name of the repository
---@return string The GitHub repository html url
function M.build_github_html_url(username, repository_name)
  return 'https://github.com/' .. username .. '/' .. repository_name
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
  -- `vim.system` arrived in 0.10. Every other Neovim requirement in the plugin
  -- is stated up front, so this one reports itself rather than surfacing as
  -- "attempt to call field 'system' (a nil value)" from inside a git call.
  if type(vim.system) ~= 'function' then
    return { 'agitate requires Neovim 0.10 or newer for git operations' }, false
  end

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

return M
