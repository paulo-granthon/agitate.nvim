describe('util', function()
  local util = require('agitate.util')

  describe('flatten_table', function()
    it('joins lines with a single space and no leading space', function()
      assert.are.equal('one two three', util.flatten_table({ 'one', 'two', 'three' }))
    end)

    it('returns an empty string for an empty table', function()
      assert.are.equal('', util.flatten_table({}))
    end)

    it('skips the requested number of leading lines', function()
      assert.are.equal('three', util.flatten_table({ 'one', 'two', 'three' }, { skip = 2 }))
    end)

    it('returns an empty string when skip covers every line', function()
      assert.are.equal('', util.flatten_table({ 'one' }, { skip = 5 }))
    end)
  end)

  describe('json_lr_trim', function()
    it('trims noise around a json object', function()
      local ok, json = util.json_lr_trim('noise {"a":1} trailing')

      assert.is_true(ok)
      assert.are.equal('{"a":1}', json)
    end)

    it('keeps nested braces intact', function()
      local ok, json = util.json_lr_trim('% {"a":{"b":2}} %')

      assert.is_true(ok)
      assert.are.equal('{"a":{"b":2}}', json)
    end)

    -- The annotation promises a pair, and callers destructure two values.
    it('returns a nil second value when there is no json', function()
      local ok, json = util.json_lr_trim('no braces at all')

      assert.is_false(ok)
      assert.is_nil(json)
    end)
  end)

  describe('build_github_remote_url', function()
    it('builds an https remote by default', function()
      assert.are.equal('https://github.com/octocat/hello.git', util.build_github_remote_url('octocat', 'hello'))
    end)

    it('builds an https remote when asked explicitly', function()
      assert.are.equal('https://github.com/octocat/hello.git', util.build_github_remote_url('octocat', 'hello', 'https'))
    end)

    it('builds the scp style form for ssh', function()
      assert.are.equal('git@github.com:octocat/hello.git', util.build_github_remote_url('octocat', 'hello', 'ssh'))
    end)

    it('rejects an unrecognised protocol instead of assuming https', function()
      assert.is_false(pcall(util.build_github_remote_url, 'octocat', 'hello', 'htps'))
    end)

    it('always ends in .git', function()
      for _, protocol in ipairs({ 'https', 'ssh' }) do
        assert.is_truthy(util.build_github_remote_url('octocat', 'hello', protocol):find('%.git$'))
      end
    end)
  end)

  describe('build_github_html_url', function()
    it('builds a url with no trailing slash', function()
      assert.are.equal('https://github.com/octocat/hello', util.build_github_html_url('octocat', 'hello'))
    end)
  end)
  describe('buffer_directory', function()
    it('returns the working directory for a buffer with no file', function()
      local previous_buffer = vim.api.nvim_get_current_buf()

      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
      local resolved = util.buffer_directory()
      vim.api.nvim_set_current_buf(previous_buffer)

      assert.are.equal(vim.fn.getcwd(), resolved)
    end)

    -- This is what decides which repository every git command acts on, so the
    -- buffer has to win over the working directory.
    it("returns the current buffer's directory, not the working directory", function()
      local directory = vim.fn.tempname()
      vim.fn.mkdir(directory, 'p')
      vim.fn.writefile({ 'x' }, directory .. '/file.txt')

      local previous_buffer = vim.api.nvim_get_current_buf()

      vim.cmd('edit ' .. vim.fn.fnameescape(directory .. '/file.txt'))
      local resolved = util.buffer_directory()
      vim.api.nvim_set_current_buf(previous_buffer)

      assert.are.equal(vim.fn.resolve(directory), vim.fn.resolve(resolved))
    end)
  end)

  describe('git', function()
    ---Builds a repository on `branch_name` with one commit.
    local function repository(branch_name)
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.system({ 'git', '-C', directory, 'init', '-b', branch_name })
      vim.fn.system({
        'git',
        '-C',
        directory,
        '-c',
        'user.name=agitate tests',
        '-c',
        'user.email=tests@agitate.invalid',
        'commit',
        '--allow-empty',
        '-m',
        'init',
        '--no-gpg-sign',
      })

      return directory
    end

    it('reports success and failure', function()
      local directory = repository('main')

      local _, ok = util.git({ 'rev-parse', 'HEAD' }, directory)
      assert.is_true(ok)

      local output, failed = util.git({ 'branch', '-d', 'no-such-branch' }, directory)
      assert.is_false(failed)
      -- git writes this to stderr, which a stdout-only runner would have lost.
      assert.is_truthy(table.concat(output, '\n'):lower():find('not found'))
    end)

    it('runs in the directory it is given', function()
      local directory = repository('given-repo')

      local output, ok = util.git({ 'symbolic-ref', '--short', 'HEAD' }, directory)

      assert.is_true(ok)
      assert.are.equal('given-repo', output[1])
    end)
  end)
end)
