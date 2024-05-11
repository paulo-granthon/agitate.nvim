describe('parse_args', function()
  local parse_args = require('lua.agitate.parse_args')

  it('should parse args', function()
    local flags = { '-a', '-b', '-c', }

    local args = { '-a', 'arg_a', '-b', 'arg_b', 'arg_c' }
    local parsed_args = parse_args(flags, args)
    assert.are.same({
      ['-a'] = 'arg_a',
      ['-b'] = 'arg_b',
      ['-c'] = 'arg_c',
    }, parsed_args)
  end)
end)
