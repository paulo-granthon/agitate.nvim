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

  describe('parse_github_remote', function()
    it('parses an https remote', function()
      local owner, repository = util.parse_github_remote('https://github.com/octocat/hello.git')

      assert.are.equal('octocat', owner)
      assert.are.equal('hello', repository)
    end)

    it('parses an https remote with no .git suffix', function()
      local owner, repository = util.parse_github_remote('https://github.com/octocat/hello')

      assert.are.equal('octocat', owner)
      assert.are.equal('hello', repository)
    end)

    it('parses the scp style ssh remote', function()
      local owner, repository = util.parse_github_remote('git@github.com:octocat/hello.git')

      assert.are.equal('octocat', owner)
      assert.are.equal('hello', repository)
    end)

    it('keeps a dot inside the repository name', function()
      local _, repository = util.parse_github_remote('git@github.com:octocat/agitate.nvim.git')

      assert.are.equal('agitate.nvim', repository)
    end)

    it('returns nil for a remote that is not GitHub', function()
      local owner, repository = util.parse_github_remote('https://gitlab.com/octocat/hello.git')

      assert.is_nil(owner)
      assert.is_nil(repository)
    end)

    it('returns nil for a nil or malformed url', function()
      assert.is_nil(util.parse_github_remote(nil))
      assert.is_nil(util.parse_github_remote('not a url'))
    end)
  end)

  describe('origin_repository', function()
    -- Agitate's own checkout has a GitHub origin, so this runs the real
    -- command rather than a stub.
    it('reads the owner and repository from the current checkout', function()
      local owner, repository = util.origin_repository()

      assert.are.equal('paulo-granthon', owner)
      assert.are.equal('agitate.nvim', repository)
    end)
  end)

  describe('current_branch', function()
    ---Creates a repository on a known branch, with one commit, and moves into it.
    ---
    ---A scratch repository rather than Agitate's own checkout: a
    ---`pull_request` workflow run checks out a detached merge commit, where
    ---there is correctly no branch name to report.
    ---
    ---The commit is required, because `git rev-parse HEAD` exits 128 on an
    ---unborn branch, and it carries its own identity because a CI runner has
    ---none configured.
    local function in_repository(name, body)
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.system({ 'git', '-C', directory, 'init', '-b', name })
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

      vim.fn.chdir(directory)

      local called_ok, err = pcall(body)

      vim.fn.chdir(previous)

      assert(called_ok, err)
    end

    it('reports the checked out branch', function()
      in_repository('trunk', function()
        assert.are.equal('trunk', util.current_branch())
      end)
    end)

    it('reports a branch whose name contains slashes', function()
      in_repository('feature/nested/name', function()
        assert.are.equal('feature/nested/name', util.current_branch())
      end)
    end)

    it('returns nil outside a repository', function()
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.chdir(directory)

      local name = util.current_branch()

      vim.fn.chdir(previous)

      assert.is_nil(name)
    end)
  end)

  describe('build_github_html_url', function()
    it('builds a url with no trailing slash', function()
      assert.are.equal('https://github.com/octocat/hello', util.build_github_html_url('octocat', 'hello'))
    end)
  end)
end)
