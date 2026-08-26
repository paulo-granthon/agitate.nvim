describe('ui.buffer', function()
  local buffer = require('agitate.ui.buffer')

  describe('parse', function()
    it('takes the first line as the title and the rest as the body', function()
      local title, body = buffer.parse({ 'Fix the thing', '', 'It is broken.' })

      assert.are.equal('Fix the thing', title)
      assert.are.equal('It is broken.', body)
    end)

    it('returns an empty body when only a title was written', function()
      local title, body = buffer.parse({ 'Fix the thing' })

      assert.are.equal('Fix the thing', title)
      assert.are.equal('', body)
    end)

    -- An accidental newline at the top should not produce an empty title.
    it('skips leading blank lines to find the title', function()
      local title, body = buffer.parse({ '', '  ', 'Fix the thing', '', 'Details.' })

      assert.are.equal('Fix the thing', title)
      assert.are.equal('Details.', body)
    end)

    it('trims trailing blank lines from the body', function()
      local _, body = buffer.parse({ 'Title', '', 'Body.', '', '' })

      assert.are.equal('Body.', body)
    end)

    it('keeps blank lines inside the body', function()
      local _, body = buffer.parse({ 'Title', '', 'One.', '', 'Two.' })

      assert.are.equal('One.\n\nTwo.', body)
    end)

    -- Markdown headings start with `#`, which is exactly why the help text is
    -- rendered as virtual lines rather than as strippable comments.
    it('keeps markdown headings in the body', function()
      local _, body = buffer.parse({ 'Title', '', '# Heading', 'text' })

      assert.are.equal('# Heading\ntext', body)
    end)

    it('trims surrounding whitespace from the title only', function()
      local title, body = buffer.parse({ '  Fix the thing  ', '', '  indented' })

      assert.are.equal('Fix the thing', title)
      assert.are.equal('  indented', body)
    end)

    it('returns nil for an empty buffer', function()
      assert.is_nil(buffer.parse({ '' }))
      assert.is_nil(buffer.parse({}))
      assert.is_nil(buffer.parse({ '', '   ', '' }))
    end)
  end)
end)

describe('ui.buffer raw mode', function()
  local buffer = require('agitate.ui.buffer')

  -- A comment has no title. Routing one through `parse` trimmed its first
  -- line and collapsed the blank line after it, while the help text claimed
  -- the first line was not treated specially.
  it('parse still splits a title when raw mode is not used', function()
    local title, body = buffer.parse({ '  spaced  ', '', 'rest' })

    assert.are.equal('spaced', title)
    assert.are.equal('rest', body)
  end)
end)

describe('ui.list', function()
  local list = require('agitate.ui.list')

  describe('render', function()
    it('renders one line per entry', function()
      local lines = list.render({
        { number = 1, title = 'First', state = 'open' },
        { number = 2, title = 'Second', state = 'open' },
      })

      assert.are.equal(2, #lines)
    end)

    it('includes the number, state and title', function()
      local lines = list.render({ { number = 42, title = 'Fix it', state = 'open' } })

      assert.is_truthy(lines[1]:find('#42', 1, true))
      assert.is_truthy(lines[1]:find('open', 1, true))
      assert.is_truthy(lines[1]:find('Fix it', 1, true))
    end)

    -- Alignment is computed from the data, so a list mixing #7 and #1024 still
    -- lines its titles up.
    it('aligns titles across differing number widths', function()
      local lines = list.render({
        { number = 7, title = 'Short', state = 'open' },
        { number = 1024, title = 'Long', state = 'open' },
      })

      assert.are.equal(lines[1]:find('Short', 1, true), lines[2]:find('Long', 1, true))
    end)

    it('aligns titles across differing state widths', function()
      local lines = list.render({
        { number = 1, title = 'A', state = 'open' },
        { number = 2, title = 'B', state = 'closed' },
      })

      assert.are.equal(lines[1]:find('A', 1, true), lines[2]:find('B', 1, true))
    end)

    -- `#` counts bytes, so a multibyte title pushed its column out by the
    -- extra bytes rather than the extra cells.
    it('aligns titles when a state contains multibyte characters', function()
      local lines = list.render({
        { number = 1, title = 'A', state = 'ok' },
        { number = 2, title = 'B', state = 'ré' },
      })

      assert.are.equal(vim.fn.strdisplaywidth(lines[1]:gsub('A$', '')), vim.fn.strdisplaywidth(lines[2]:gsub('B$', '')))
    end)

    it('returns no lines for no entries', function()
      assert.are.same({}, list.render({}))
    end)

    it('tolerates a missing state or title', function()
      local lines = list.render({ { number = 3 } })

      assert.is_truthy(lines[1]:find('#3', 1, true))
    end)
  end)
end)

describe('ui.document', function()
  local document = require('agitate.ui.document')

  describe('render', function()
    local entry = {
      number = 42,
      title = 'Fix the thing',
      state = 'open',
      user = { login = 'octocat' },
      body = 'It is broken.',
      html_url = 'https://github.com/acme/thing/issues/42',
    }

    it('leads with the number and title', function()
      assert.are.equal('# #42 Fix the thing', document.render(entry)[1])
    end)

    it('includes the state, author and url', function()
      local text = table.concat(document.render(entry), '\n')

      assert.is_truthy(text:find('State: open', 1, true))
      assert.is_truthy(text:find('Author: octocat', 1, true))
      assert.is_truthy(text:find('https://github.com/acme/thing/issues/42', 1, true))
    end)

    it('includes the body', function()
      assert.is_truthy(table.concat(document.render(entry), '\n'):find('It is broken.', 1, true))
    end)

    -- GitHub returns nil from some endpoints and an empty string from others
    -- for the same thing: an author who wrote no description.
    it('says so when there is no body', function()
      for _, body in ipairs({ '', '   ' }) do
        local copy = vim.tbl_extend('force', entry, { body = body })

        assert.is_truthy(table.concat(document.render(copy), '\n'):find('No description provided', 1, true))
      end

      local without = vim.tbl_extend('force', entry, {})
      without.body = nil

      assert.is_truthy(table.concat(document.render(without), '\n'):find('No description provided', 1, true))
    end)

    it('renders each comment under its author', function()
      local text = table.concat(
        document.render(entry, {
          { user = { login = 'alice' }, body = 'First.' },
          { user = { login = 'bob' }, body = 'Second.' },
        }),
        '\n'
      )

      assert.is_truthy(text:find('## alice', 1, true))
      assert.is_truthy(text:find('First.', 1, true))
      assert.is_truthy(text:find('## bob', 1, true))
      assert.is_truthy(text:find('Second.', 1, true))
    end)

    it('appends the extra header lines', function()
      assert.is_truthy(table.concat(document.render(entry, nil, { '- Base: main' }), '\n'):find('- Base: main', 1, true))
    end)

    it('tolerates missing fields', function()
      local lines = document.render({ number = 1 })

      assert.is_truthy(lines[1]:find('#1', 1, true))
      assert.is_truthy(table.concat(lines, '\n'):find('unknown', 1, true))
    end)

    it('keeps a multi line body as separate lines', function()
      local copy = vim.tbl_extend('force', entry, { body = 'one\ntwo' })
      local lines = document.render(copy)

      assert.is_truthy(vim.tbl_contains(lines, 'one'))
      assert.is_truthy(vim.tbl_contains(lines, 'two'))
    end)
  end)
end)
