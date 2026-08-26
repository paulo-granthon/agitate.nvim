describe('parse_args', function()
  local parse_args = require('agitate.parse_args')

  it('should parse args', function()
    local flags = { '-a', '-b', '-c' }

    local args = { '-a', 'arg_a', '-b', 'arg_b', 'arg_c' }
    local parsed_args = parse_args(flags, args)
    assert.are.same({
      ['-a'] = 'arg_a',
      ['-b'] = 'arg_b',
      ['-c'] = 'arg_c',
    }, parsed_args)
  end)

  it('fills flags positionally when none are named', function()
    local parsed_args = parse_args({ '-a', '-b' }, { 'first', 'second' })

    assert.are.same({ ['-a'] = 'first', ['-b'] = 'second' }, parsed_args)
  end)

  it('lets an explicit flag win over positional order', function()
    local parsed_args = parse_args({ '-a', '-b' }, { '-b', 'named', 'positional' })

    assert.are.same({ ['-a'] = 'positional', ['-b'] = 'named' }, parsed_args)
  end)

  it('returns an empty leftover table when everything matched', function()
    local _, leftover = parse_args({ '-a' }, { '-a', 'value' })

    assert.are.same({}, leftover)
  end)

  it('returns positional arguments that ran out of flags as leftovers', function()
    local parsed_args, leftover = parse_args({ '-a' }, { 'first', 'second', 'third' })

    assert.are.same({ ['-a'] = 'first' }, parsed_args)
    assert.are.same({ 'second', 'third' }, leftover)
  end)

  -- An undeclared flag must take its value down with it. Leaving the value
  -- unconsumed let it fill the first declared flag positionally, so a typo in
  -- the flag name quietly assigned the value to something else.
  it('returns an undeclared flag together with its value as leftovers', function()
    local parsed_args, leftover = parse_args({ '-a' }, { '-z', 'value' })

    assert.is_nil(parsed_args['-z'])
    assert.is_nil(parsed_args['-a'])
    assert.are.same({ '-z', 'value' }, leftover)
  end)

  it('still fills a declared flag from a positional given alongside a bad flag', function()
    local parsed_args, leftover = parse_args({ '-a' }, { '-z', 'value', 'positional' })

    assert.are.same({ ['-a'] = 'positional' }, parsed_args)
    assert.are.same({ '-z', 'value' }, leftover)
  end)

  it('reports a bare undeclared flag as a leftover', function()
    local _, leftover = parse_args({ '-a' }, { '-z' })

    assert.are.same({ '-z' }, leftover)
  end)

  -- Reported separately from leftovers: `-r` with no value is a typo in the
  -- invocation, not an unrecognised argument, and deserves a different message.
  it('reports a declared flag with no value as incomplete, not unrecognised', function()
    local parsed_args, leftover, incomplete = parse_args({ '-a', '-b' }, { '-a', '-b', 'value' })

    assert.are.same({ ['-b'] = 'value' }, parsed_args)
    assert.are.same({}, leftover)
    assert.are.same({ '-a' }, incomplete)
  end)

  it('reports a trailing declared flag with nothing after it as incomplete', function()
    local _, leftover, incomplete = parse_args({ '-a' }, { '-a' })

    assert.are.same({}, leftover)
    assert.are.same({ '-a' }, incomplete)
  end)

  it('returns an empty incomplete table when every flag got its value', function()
    local _, _, incomplete = parse_args({ '-a' }, { '-a', 'value' })

    assert.are.same({}, incomplete)
  end)

  it('handles a nil argument list', function()
    local parsed_args, leftover, incomplete = parse_args({ '-a' }, nil)

    assert.are.same({}, parsed_args)
    assert.are.same({}, leftover)
    assert.are.same({}, incomplete)
  end)
end)
