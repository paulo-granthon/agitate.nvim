---Parses raw command arguments into a table keyed by flag.
---
---Arguments may be given explicitly as a `-flag value` pair, or positionally,
---in which case they fill the declared flags in the order those flags were
---declared. Explicit pairs are resolved first, so a positional argument never
---claims a flag that was named later in the same invocation.
---
---Anything that matches no declared flag is returned as the second value
---rather than being silently dropped.
---
---@param flags string[] The declared flags, in positional fill order
---@param args string[]|nil The raw arguments, as received from `opts.fargs`
---@return table<string, string> parsed The value found for each declared flag
---@return string[] leftover The arguments that matched no declared flag
return function(flags, args)
  args = args or {}

  local declared = {}
  for _, flag in ipairs(flags) do
    declared[flag] = true
  end

  local parsed_args = {}
  local consumed = {}

  -- Explicit `-flag value` pairs. A flag whose next argument is missing or is
  -- itself a flag consumes nothing, and falls through to the leftovers.
  local i = 1
  while i <= #args do
    local arg = args[i]

    if declared[arg] then
      local value = args[i + 1]

      if value and value:sub(1, 1) ~= '-' then
        parsed_args[arg] = value
        consumed[i], consumed[i + 1] = true, true
        i = i + 1
      end
    end

    i = i + 1
  end

  -- Positional arguments fill whichever declared flags are still unset.
  local next_flag = 1
  for index = 1, #args do
    if not consumed[index] and args[index]:sub(1, 1) ~= '-' then
      while next_flag <= #flags and parsed_args[flags[next_flag]] do
        next_flag = next_flag + 1
      end

      if next_flag > #flags then
        break
      end

      parsed_args[flags[next_flag]] = args[index]
      consumed[index] = true
    end
  end

  local leftover = {}
  for index = 1, #args do
    if not consumed[index] then
      leftover[#leftover + 1] = args[index]
    end
  end

  return parsed_args, leftover
end
