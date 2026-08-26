---Parses raw command arguments into a table keyed by flag.
---
---Arguments may be given explicitly as a `-flag value` pair, or positionally,
---in which case they fill the declared flags in the order those flags were
---declared. Explicit pairs are resolved first, so a positional argument never
---claims a flag that was named later in the same invocation.
---
---Nothing is silently dropped. Anything that could not be matched comes back
---in one of the two remaining return values, and the two are kept separate
---because they need different messages: an unrecognised argument is a typo in
---the name, while a declared flag with no value is a typo in the invocation.
---
---@param flags string[] The declared flags, in positional fill order
---@param args string[]|nil The raw arguments, as received from `opts.fargs`
---@return table<string, string> parsed The value found for each declared flag
---@return string[] leftover Arguments matching no declared flag
---@return string[] incomplete Declared flags given without a usable value
return function(flags, args)
  args = args or {}

  local declared = {}
  for _, flag in ipairs(flags) do
    declared[flag] = true
  end

  local parsed_args = {}
  -- `consumed` means "not available to fill a flag positionally".
  -- `rejected` means "must still be reported". An undeclared flag and its
  -- value are both, which is why the two are tracked separately: marking them
  -- only consumed would stop them being reinterpreted but also drop them
  -- silently, and marking them only rejected would let the value fill a flag.
  local consumed = {}
  local rejected = {}
  local incomplete = {}

  ---Reports whether the argument at `index` can serve as a value.
  ---A flag is never a value, so `-a -b` leaves `-a` without one.
  local function value_at(index)
    local value = args[index]

    if value and value:sub(1, 1) ~= '-' then
      return value
    end

    return nil
  end

  local index = 1
  while index <= #args do
    local arg = args[index]

    if arg:sub(1, 1) == '-' then
      local value = value_at(index + 1)

      if declared[arg] then
        if value then
          parsed_args[arg] = value
          consumed[index], consumed[index + 1] = true, true
          index = index + 1
        else
          -- Declared but unusable. Consumed so it is not also reported as
          -- unrecognised, and recorded separately so the caller can say which
          -- flag is missing its value.
          consumed[index] = true
          incomplete[#incomplete + 1] = arg
        end
      else
        -- An undeclared flag takes its value down with it. Leaving the value
        -- available would let it fill the first declared flag positionally,
        -- so `-z value` would quietly become `-r value`.
        consumed[index], rejected[index] = true, true

        if value then
          consumed[index + 1], rejected[index + 1] = true, true
          index = index + 1
        end
      end
    end

    index = index + 1
  end

  -- Positional arguments fill whichever declared flags are still unset.
  local next_flag = 1
  for position = 1, #args do
    if not consumed[position] and args[position]:sub(1, 1) ~= '-' then
      while next_flag <= #flags and parsed_args[flags[next_flag]] do
        next_flag = next_flag + 1
      end

      if next_flag > #flags then
        break
      end

      parsed_args[flags[next_flag]] = args[position]
      consumed[position] = true
    end
  end

  local leftover = {}
  for position = 1, #args do
    if rejected[position] or not consumed[position] then
      leftover[#leftover + 1] = args[position]
    end
  end

  return parsed_args, leftover, incomplete
end
