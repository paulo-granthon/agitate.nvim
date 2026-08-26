local M = {}

---Renders an issue or pull request, with its comments, into markdown lines.
---
---Issues and pull requests share this because GitHub gives them the same
---shape: a title, an author, a body, and a list of comments. Anything specific
---to one of them is passed in through `extra`.
---
---@param entry table The issue or pull request, as GitHub returns it
---@param comments table[]|nil The comments, as GitHub returns them
---@param extra string[]|nil Additional detail lines for the header
---@return string[] lines
function M.render(entry, comments, extra)
  local lines = {
    '# #' .. tostring(entry.number) .. ' ' .. tostring(entry.title or ''),
    '',
    '- State: ' .. tostring(entry.state or 'unknown'),
    '- Author: ' .. tostring((entry.user or {}).login or 'unknown'),
  }

  for _, line in ipairs(extra or {}) do
    lines[#lines + 1] = line
  end

  if entry.html_url then
    lines[#lines + 1] = '- URL: ' .. tostring(entry.html_url)
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = '---'
  lines[#lines + 1] = ''

  -- A body of `nil` and a body of `''` both mean the author wrote nothing, and
  -- GitHub uses each depending on the endpoint.
  local body = entry.body

  if body and body:match('%S') then
    for _, line in ipairs(vim.split(body, '\n')) do
      lines[#lines + 1] = line
    end
  else
    lines[#lines + 1] = '*No description provided.*'
  end

  for _, comment in ipairs(comments or {}) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = '---'
    lines[#lines + 1] = ''
    lines[#lines + 1] = '## ' .. tostring((comment.user or {}).login or 'unknown')
    lines[#lines + 1] = ''

    for _, line in ipairs(vim.split(comment.body or '', '\n')) do
      lines[#lines + 1] = line
    end
  end

  return lines
end

---Opens lines in a read only markdown scratch buffer.
---@param name string The buffer name
---@param lines string[] The contents
function M.open(name, lines)
  local buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buffer })
  vim.api.nvim_buf_set_name(buffer, name)

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  -- `nvim_buf_set_lines` marks the buffer changed, so a buffer nobody can
  -- edit would otherwise sit there showing `[+]`.
  vim.api.nvim_set_option_value('modified', false, { buf = buffer })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buffer })

  vim.api.nvim_win_set_buf(0, buffer)

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(buffer, { force = true })
  end, { buffer = buffer, nowait = true, silent = true })
end

return M
