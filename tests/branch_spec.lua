describe('core.branch', function()
  local branch = require('agitate.core.branch')

  describe('plan_delete', function()
    it('deletes the branch that was asked for', function()
      local plan = branch._plan_delete('feature', 'main', true)

      assert.is_true(plan.ok)
      assert.are.equal('feature', plan.branch)
      assert.is_true(plan.delete_remote)
    end)

    it('skips the remote when the branch has no counterpart there', function()
      assert.is_false(branch._plan_delete('feature', 'main', false).delete_remote)
    end)

    -- git itself refuses this, and switching away on the user's behalf would be
    -- a surprising side effect of asking to delete something.
    it('refuses to delete the current branch', function()
      local plan = branch._plan_delete('main', 'main', true)

      assert.is_false(plan.ok)
      assert.is_truthy(plan.reason:find('current branch', 1, true))
    end)

    -- There is no default. Defaulting to the current branch and then refusing
    -- to delete the current branch made the no argument form unusable.
    it('refuses when no branch is named', function()
      for _, given in ipairs({ '' }) do
        local plan = branch._plan_delete(given, 'main', false)

        assert.is_false(plan.ok)
        assert.is_truthy(plan.reason:find('no branch name given', 1, true))
      end

      local plan = branch._plan_delete(nil, 'main', false)

      assert.is_false(plan.ok)
      assert.is_truthy(plan.reason:find('no branch name given', 1, true))
    end)
  end)

  describe('confirm_prompt', function()
    it('names both targets when the remote branch exists', function()
      local prompt = branch._confirm_prompt('feature', true, 'origin')

      assert.is_truthy(prompt:find('feature', 1, true))
      assert.is_truthy(prompt:find('origin', 1, true))
      assert.is_truthy(prompt:find('locally and from', 1, true))
    end)

    it('says the remote is left alone without claiming what is on it', function()
      local prompt = branch._confirm_prompt('feature', false, 'origin')

      assert.is_truthy(prompt:find('left alone', 1, true))
      -- The check is local, so the prompt must not assert the remote's state.
      assert.is_nil(prompt:find('no counterpart', 1, true))
    end)
  end)

  describe('current_branch', function()
    ---Creates a repository on a known branch, with one commit, and moves into it.
    ---
    ---Asserting against Agitate's own checkout looked fine locally and failed
    ---in CI: a `pull_request` run checks out a detached merge commit, where
    ---there is correctly no branch name to report. A scratch repository makes
    ---the answer the same everywhere.
    ---
    ---The commit is required. On an unborn branch `git rev-parse HEAD` exits
    ---128, so an empty repository reports no branch either.
    local function in_repository(name, body)
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.system({ 'git', '-C', directory, 'init', '-b', name })
      -- Identity is set per command: a CI runner has none configured, and
      -- without it `git commit` refuses and the branch stays unborn.
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
        assert.are.equal('trunk', branch._current_branch())
      end)
    end)

    it('reports a branch whose name contains slashes', function()
      in_repository('feature/nested/name', function()
        assert.are.equal('feature/nested/name', branch._current_branch())
      end)
    end)

    it('returns nil outside a repository', function()
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.chdir(directory)

      local name = branch._current_branch()

      vim.fn.chdir(previous)

      assert.is_nil(name)
    end)
  end)

  describe('exists_on_remote', function()
    it('is false for a branch that does not exist', function()
      assert.is_false(branch._exists_on_remote('origin', 'a-branch-that-should-never-exist'))
    end)
  end)
  describe('git', function()
    ---Creates a repository with one commit and moves into it.
    local function in_repository(body)
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.system({ 'git', '-C', directory, 'init', '-b', 'main' })
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

    it('reports success and failure through its second return value', function()
      in_repository(function()
        local _, ok = branch._git({ 'rev-parse', 'HEAD' })
        assert.is_true(ok)

        local output, failed = branch._git({ 'branch', '-d', 'no-such-branch' })
        assert.is_false(failed)
        assert.is_true(#output > 0)
      end)
    end)

    -- `|` is a valid git ref character and an Ex command separator. Routed
    -- through `vim.cmd('G branch -d ' .. ref)` the suffix ran as a second Ex
    -- command, so a branch named `topic|qall` quit Neovim on delete.
    it('handles a ref containing a pipe as one argument', function()
      in_repository(function()
        local _, created = branch._git({ 'branch', 'topic|qall' })
        assert.is_true(created)

        local _, deleted = branch._git({ 'branch', '-D', 'topic|qall' })
        assert.is_true(deleted)

        local _, gone = branch._git({ 'rev-parse', '--verify', '--quiet', 'refs/heads/topic|qall' })
        assert.is_false(gone)
      end)
    end)

    -- The remote deletion is gated on this failing, so if git ever stopped
    -- refusing here the gate would silently open.
    it('refuses to delete an unmerged branch without force', function()
      in_repository(function()
        branch._git({ 'checkout', '-b', 'unmerged' })
        vim.fn.writefile({ 'work' }, 'work.txt')
        branch._git({ 'add', 'work.txt' })
        branch._git({
          '-c',
          'user.name=agitate tests',
          '-c',
          'user.email=tests@agitate.invalid',
          'commit',
          '-m',
          'work',
          '--no-gpg-sign',
        })
        branch._git({ 'checkout', 'main' })

        local _, safe = branch._git({ 'branch', '-d', 'unmerged' })
        assert.is_false(safe)

        local _, forced = branch._git({ 'branch', '-D', 'unmerged' })
        assert.is_true(forced)
      end)
    end)
  end)
end)
