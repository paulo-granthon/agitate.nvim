local M = {}

local ok, agitate_error = pcall(require, 'agitate.error')
if not ok then
  local message = require('agitate.const.error').import
  vim.notify(message, vim.log.levels.ERROR)
  error(message, 0)
end

local github_ok, github_or_err = pcall(require, 'agitate.service.github')
if not github_ok then
  agitate_error.throw(github_or_err)
  error(github_or_err, 0)
end

local github = github_or_err

local parse_args = require('agitate.parse_args')

---Substitutes the placeholders GitHub leaves in a license body.
---
---The API returns the template verbatim, with `[year]` and `[fullname]`
---still in it. Writing that to disk unchanged produces a LICENSE that names
---nobody, which is worse than no LICENSE at all because it looks finished.
---@param body string The license text as GitHub returns it
---@param year string|number The copyright year
---@param author string The copyright holder
---@return string
function M.apply_license_placeholders(body, year, author)
  -- `gsub` reads `%` in a replacement string as a capture reference, so a name
  -- containing one would otherwise corrupt the output rather than appear in it.
  local safe_author = tostring(author):gsub('%%', '%%%%')
  local safe_year = tostring(year):gsub('%%', '%%%%')

  return (body:gsub('%[year%]', safe_year):gsub('%[fullname%]', safe_author):gsub('<year>', safe_year):gsub('<name of author>', safe_author))
end

---Reports whether a string is a usable GitHub account name.
---
---GitHub allows alphanumerics and single hyphens, not leading or trailing,
---up to 39 characters. Worth checking before writing one into a YAML flow
---sequence, where a `]` or a `,` would silently produce a broken file.
---@param username string
---@return boolean
function M.is_valid_username(username)
  if type(username) ~= 'string' or #username == 0 or #username > 39 then
    return false
  end

  return username:match('^%w[%w%-]*$') ~= nil and not username:find('%-%-') and username:sub(-1) ~= '-'
end

---Builds the contents of a `FUNDING.yml`.
---@param username string The GitHub username to list as a sponsor target
---@return string[] lines
function M.funding_content(username)
  return {
    '# These are supported funding model platforms',
    '',
    'github: [' .. username .. ']',
  }
end

---Writes lines to a path, asking before replacing an existing file.
---@param path string Absolute path to write
---@param lines string[] The contents
---@param description string What is being written, for the messages
local function write_file(path, lines, description)
  local exists = vim.fn.filereadable(path) == 1

  if exists then
    local choice = vim.fn.confirm(path .. ' already exists. Replace it?', '&Replace\n&Cancel', 2, 'Question')

    if choice ~= 1 then
      return vim.notify('Left ' .. path .. ' untouched.', vim.log.levels.INFO)
    end
  end

  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  if vim.fn.writefile(lines, path) ~= 0 then
    return agitate_error.throw('core.file -- Error: could not write ' .. path)
  end

  vim.notify('Wrote ' .. description .. ' to ' .. path, vim.log.levels.INFO)
end

---Resolves a path relative to the current working directory.
---@param name string
---@return string
local function cwd_path(name)
  return vim.fn.getcwd() .. '/' .. name
end

---Prompts the user to pick one entry, or passes a given choice straight through.
---
---`vim.ui.select` is used rather than a custom buffer because this is a one
---shot choice, not something to browse back and forth in. It also picks up
---whatever ui-select plugin the user already has, without Agitate depending
---on one.
---@param given string|nil A choice supplied on the command line
---@param items string[] The available choices
---@param prompt string
---@param callback fun(choice: string)
local function choose(given, items, prompt, callback)
  if given then
    return callback(given)
  end

  vim.ui.select(items, { prompt = prompt }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

---Add a `.gitignore` from a GitHub template
---@param optional_parameters? table<string> `-t` selects the template by name.
---Without it, the available templates are offered for selection.
function M.Gitignore(optional_parameters)
  local options = require('agitate.config').options
  local parameters, leftover, incomplete = parse_args({ '-t' }, optional_parameters)

  if #incomplete > 0 then
    return agitate_error.throw('core.file.Gitignore -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw('core.file.Gitignore -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local token = options.github_access_token

  local function fetch(template)
    github.get_gitignore_template(token, template, function(fetch_ok, result)
      if not fetch_ok then
        return agitate_error.throw(result)
      end

      -- An empty or missing `source` would write an empty `.gitignore`, and
      -- since this replaces an existing file after confirmation, silently
      -- emptying one is worse than refusing. The LICENSE path already refuses.
      if type(result.source) ~= 'string' or not result.source:match('%S') then
        return agitate_error.throw('core.file.Gitignore -- Error: GitHub returned no content for the `' .. template .. '` template.')
      end

      write_file(cwd_path('.gitignore'), vim.split(result.source, '\n'), 'the ' .. template .. ' gitignore template')
    end)
  end

  if parameters['-t'] then
    return fetch(parameters['-t'])
  end

  github.list_gitignore_templates(token, function(list_ok, templates)
    if not list_ok then
      return agitate_error.throw(templates)
    end

    choose(nil, templates, 'Gitignore template', fetch)
  end)
end

---Add a `LICENSE` from a GitHub template
---@param optional_parameters? table<string> Parameters can be passed in order or explicitly
---with their corresponding flags:
---  -l: The license key, such as `mit`. Without it, the licenses are offered for selection.
---  -a: The copyright holder. Defaults to `file.license.author`, then the configured username.
function M.License(optional_parameters)
  local options = require('agitate.config').options
  local parameters, leftover, incomplete = parse_args({ '-l', '-a' }, optional_parameters)

  if #incomplete > 0 then
    return agitate_error.throw('core.file.License -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw('core.file.License -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local token = options.github_access_token
  -- Navigated defensively: `file` and `file.license` are optional in the
  -- config type, so a hand assembled options table can omit them and the
  -- fallback to `github_username` should still work rather than raise.
  local configured_author = options.file and options.file.license and options.file.license.author
  local author = parameters['-a'] or configured_author or options.github_username

  if not author then
    return agitate_error.throw(
      'core.file.License -- Error: no copyright holder to write.' .. '\nPass `-a`, or set `file.license.author` or `github_username` in your configuration.'
    )
  end

  local function fetch(key)
    github.get_license(token, key, function(fetch_ok, result)
      if not fetch_ok then
        return agitate_error.throw(result)
      end

      if not result.body then
        return agitate_error.throw('core.file.License -- Error: GitHub returned no text for the `' .. key .. '` license.')
      end

      local body = M.apply_license_placeholders(result.body, os.date('%Y'), author)

      write_file(cwd_path('LICENSE'), vim.split(body, '\n'), (result.name or key) .. ' license')
    end)
  end

  if parameters['-l'] then
    return fetch(parameters['-l'])
  end

  github.list_licenses(token, function(list_ok, licenses)
    if not list_ok then
      return agitate_error.throw(licenses)
    end

    local keys = {}
    local labels = {}

    for _, license in ipairs(licenses) do
      keys[#keys + 1] = license.key
      labels[license.key] = license.name or license.key
    end

    vim.ui.select(keys, {
      prompt = 'License',
      format_item = function(key)
        return labels[key]
      end,
    }, function(choice)
      if choice then
        fetch(choice)
      end
    end)
  end)
end

---Add a `.github/FUNDING.yml` pointing at a GitHub sponsors profile
---@param optional_parameters? table<string> `-u` sets the username. Defaults to the configured one.
function M.Funding(optional_parameters)
  local options = require('agitate.config').options
  local parameters, leftover, incomplete = parse_args({ '-u' }, optional_parameters)

  if #incomplete > 0 then
    return agitate_error.throw('core.file.Funding -- Error: missing a value for ' .. table.concat(incomplete, ' '))
  end

  if #leftover > 0 then
    return agitate_error.throw('core.file.Funding -- Error: unrecognised arguments: ' .. table.concat(leftover, ' '))
  end

  local username = parameters['-u'] or options.github_username

  if not username then
    return agitate_error.throw('core.file.Funding -- Error: no username to fund. Pass `-u` or set `github_username`.')
  end

  -- The name goes into a YAML flow sequence, where a `]` or a `,` would
  -- produce a file that looks written but does not parse.
  if not M.is_valid_username(username) then
    return agitate_error.throw('core.file.Funding -- Error: `' .. username .. '` is not a valid GitHub account name.')
  end

  write_file(cwd_path('.github/FUNDING.yml'), M.funding_content(username), 'a funding file')
end

return M
