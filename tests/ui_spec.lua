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

    it('returns no lines for no entries', function()
      assert.are.same({}, list.render({}))
    end)

    it('tolerates a missing state or title', function()
      local lines = list.render({ { number = 3 } })

      assert.is_truthy(lines[1]:find('#3', 1, true))
    end)
  end)
end)
