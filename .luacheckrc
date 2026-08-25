std = 'luajit'
max_line_length = 160

read_globals = {
  'vim',
}

exclude_files = {
  '.luarocks',
  'lua_modules',
}

files['tests/'] = {
  std = '+busted',
}
