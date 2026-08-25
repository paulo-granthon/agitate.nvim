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

  it('returns undeclared flags as leftovers instead of accepting them', function()
    local parsed_args, leftover = parse_args({ '-a' }, { '-z', 'value' })

    assert.is_nil(parsed_args['-z'])
    assert.are.same({ '-z' }, leftover)
    assert.are.same({ ['-a'] = 'value' }, parsed_args)
  end)

  it('treats a declared flag with no value as a leftover', function()
    local parsed_args, leftover = parse_args({ '-a', '-b' }, { '-a', '-b', 'value' })

    assert.are.same({ ['-b'] = 'value' }, parsed_args)
    assert.are.same({ '-a' }, leftover)
  end)

  it('handles a nil argument list', function()
    local parsed_args, leftover = parse_args({ '-a' }, nil)

    assert.are.same({}, parsed_args)
    assert.are.same({}, leftover)
  end)
end)
