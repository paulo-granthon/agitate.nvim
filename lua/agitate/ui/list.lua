local M = {}

local NAMESPACE = vim.api.nvim_create_namespace('agitate_list')

---Pads a string to a display width, without truncating anything longer.
---
---Measured in display cells rather than bytes. `#` counts bytes, so a title
---containing accented, CJK or emoji characters threw the column alignment out
---by however many extra bytes it used.
---@param value string
---@param width number
---@return string
local function pad(value, width)
  return value .. string.rep(' ', math.max(width - vim.fn.strdisplaywidth(value), 0))
end

---Renders entries into aligned lines.
---
---The number column is padded to the width of the widest number present, so
---the titles line up regardless of whether the list holds `#7` or `#1024`.
---Alignment is computed from the data rather than a fixed guess, which is why
---this is a pure function and can be tested directly.
---
---@param entries table[] Each needs `number`; `title` and `state` render empty when absent
---@return string[] lines
function M.render(entries)
  local number_width = 0
  local state_width = 0

  for _, entry in ipairs(entries) do
    number_width = math.max(number_width, vim.fn.strdisplaywidth('#' .. tostring(entry.number)))
    state_width = math.max(state_width, vim.fn.strdisplaywidth(tostring(entry.state or '')))
  end

  local lines = {}

  for _, entry in ipairs(entries) do
    lines[#lines + 1] = pad('#' .. tostring(entry.number), number_width)
      .. '  '
      .. pad(tostring(entry.state or ''), state_width)
      .. '  '
      .. tostring(entry.title or '')
  end

  return lines
end

---Opens a read only buffer listing the entries, with per line actions.
---
---A dedicated buffer rather than the quickfix list, so the rendering and the
---keys belong to Agitate and do not disturb whatever the user already has in
---quickfix.
---
---@param opts table `{ name = string, entries = table[], keymaps = table<string, fun(entry: table)>, help = string[]|nil }`
function M.open(opts)
  local buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  vim.api.nvim_set_option_value('filetype', 'agitate-list', { buf = buffer })
  vim.api.nvim_buf_set_name(buffer, opts.name)

  local lines = M.render(opts.entries)

  if #lines == 0 then
    lines = { 'Nothing to show.' }
  end

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  -- `nvim_buf_set_lines` marks the buffer changed, so a buffer nobody can
  -- edit would otherwise sit there showing `[+]`.
  vim.api.nvim_set_option_value('modified', false, { buf = buffer })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buffer })

  vim.api.nvim_win_set_buf(0, buffer)

  if opts.help then
    local virtual_lines = { { { '', 'Comment' } } }
    for _, line in ipairs(opts.help) do
      virtual_lines[#virtual_lines + 1] = { { line, 'Comment' } }
    end

    vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, math.max(#lines - 1, 0), 0, {
      virt_lines = virtual_lines,
    })
  end

  for key, action in pairs(opts.keymaps or {}) do
    vim.keymap.set('n', key, function()
      local entry = opts.entries[vim.api.nvim_win_get_cursor(0)[1]]

      if entry then
        action(entry)
      end
    end, { buffer = buffer, nowait = true, silent = true })
  end

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(buffer, { force = true })
  end, { buffer = buffer, nowait = true, silent = true })
end

return M
