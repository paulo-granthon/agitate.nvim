local M = {}

local NAMESPACE = vim.api.nvim_create_namespace('agitate_editor')

---Splits edited buffer lines into a title and a body.
---
---The shape is the one `git commit` established and fugitive users already
---have in their fingers: the first line is the subject, everything after it is
---the body. Leading and trailing blank lines are discarded so an accidental
---newline at the top does not become an empty title.
---
---Instructions are deliberately not carried in the buffer text. `git commit`
---puts them in `#` comment lines and then has to strip them, which collides
---with Markdown headings. Here they are rendered as virtual lines instead, so
---everything in the buffer is content and nothing needs stripping.
---
---@param lines string[] The buffer contents
---@return string|nil title `nil` when there is nothing to submit
---@return string body
function M.parse(lines)
  local first = nil

  for index, line in ipairs(lines) do
    if line:match('%S') then
      first = index
      break
    end
  end

  if not first then
    return nil, ''
  end

  local title = vim.trim(lines[first])

  local body = {}
  for index = first + 1, #lines do
    body[#body + 1] = lines[index]
  end

  -- Trim blank lines from both ends of the body, so the usual blank line
  -- separating title from body does not become part of it.
  while body[1] and not body[1]:match('%S') do
    table.remove(body, 1)
  end

  while body[#body] and not body[#body]:match('%S') do
    table.remove(body)
  end

  return title, table.concat(body, '\n')
end

---Opens a scratch buffer for composing a title and body.
---
---Writing the buffer submits it. Closing without writing abandons it, and an
---empty buffer submits nothing, so there are two ways to change your mind and
---neither of them needs a special key.
---
---`opts.raw` submits the buffer verbatim as the body, with an empty title.
---A comment has no title, so putting one through the title split trimmed its
---first line and collapsed the blank line after it, which the help text then
---described inaccurately.
---
---@param opts table `{ name = string, help = string[]|nil, initial = string[]|nil, raw = boolean|nil }`
---@param callback fun(title: string, body: string) Called once, on submit
function M.open(opts, callback)
  local buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buffer })
  vim.api.nvim_set_option_value('buftype', 'acwrite', { buf = buffer })
  vim.api.nvim_buf_set_name(buffer, opts.name)

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, opts.initial or { '' })

  vim.api.nvim_win_set_buf(0, buffer)

  if opts.help then
    local virtual_lines = {}
    for _, line in ipairs(opts.help) do
      virtual_lines[#virtual_lines + 1] = { { line, 'Comment' } }
    end

    -- Anchored above the first line rather than below the last. Pinning it to
    -- whatever the last line was at creation meant it drifted into the middle
    -- of the buffer as soon as the user typed a body. Either way it is virtual
    -- text, so it can never be submitted as part of the issue.
    vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, 0, 0, {
      virt_lines = virtual_lines,
      virt_lines_above = true,
    })
  end

  -- Deliberately not `once`. An empty buffer submits nothing and returns, and
  -- with `once` that first write also removed the handler, so the user could
  -- type the issue and write again to no effect at all. On success the buffer
  -- is deleted, which takes the autocommand with it.
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = buffer,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      local title, body

      if opts.raw then
        local text = table.concat(lines, '\n')

        title, body = text:match('%S') and '' or nil, text
      else
        title, body = M.parse(lines)
      end

      vim.api.nvim_set_option_value('modified', false, { buf = buffer })

      if not title then
        vim.notify('Nothing to submit, the buffer was empty.', vim.log.levels.WARN)

        return
      end

      vim.api.nvim_buf_delete(buffer, { force = true })

      callback(title, body)
    end,
  })

  vim.cmd('startinsert')
end

return M
