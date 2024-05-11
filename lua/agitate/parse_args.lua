return function(flags, args)
  local parsed_args = {}
  local skip = {}
  for i = 1, #args do
    skip[i] = false
  end

  local i = 1
  while i <= #args do
    if not skip[i] then
      local arg = args[i]

      if arg:sub(1, 1) == '-' then
        local flag = arg
        local value = args[i + 1] or nil

        parsed_args[flag] = value

        skip[i + 1] = true
      end
    end
    i = i + 1
  end

  local j = 1
  i = 1
  while i <= #args do
    local arg = args[i]

    if not skip[i] and arg:sub(1, 1) ~= '-' then
      while j <= #flags do
        local flag = flags[j]

        if not parsed_args[flag] then
          parsed_args[flag] = arg

          break
        end

        j = j + 1
      end
    end

    i = i + 1
  end

  return parsed_args
end
