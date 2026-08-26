std = 'luajit'
max_line_length = 160

read_globals = {
  'vim',
}

-- Globs, not directory names. luacheck matches these against file paths, so a
-- bare directory name excludes nothing inside it and a local rocks tree in the
-- workspace would get linted.
exclude_files = {
  '.luarocks/**',
  'lua_modules/**',
}

files['tests/'] = {
  std = '+busted',
}
