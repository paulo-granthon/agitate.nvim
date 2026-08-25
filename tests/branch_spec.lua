describe('core.branch', function()
  local branch = require('agitate.core.branch')

  describe('plan_delete', function()
    it('deletes the branch that was asked for', function()
      local plan = branch.plan_delete('feature', 'main', true)

      assert.is_true(plan.ok)
      assert.are.equal('feature', plan.branch)
      assert.is_true(plan.delete_remote)
    end)

    it('skips the remote when the branch has no counterpart there', function()
      assert.is_false(branch.plan_delete('feature', 'main', false).delete_remote)
    end)

    -- git itself refuses this, and switching away on the user's behalf would be
    -- a surprising side effect of asking to delete something.
    it('refuses to delete the current branch', function()
      local plan = branch.plan_delete('main', 'main', true)

      assert.is_false(plan.ok)
      assert.is_truthy(plan.reason:find('current branch', 1, true))
    end)

    it('refuses when no branch is given and HEAD is detached', function()
      local plan = branch.plan_delete(nil, nil, false)

      assert.is_false(plan.ok)
      assert.is_truthy(plan.reason:find('could not be determined', 1, true))
    end)

    -- Defaulting to the current branch would always hit the refusal above, so
    -- an empty argument has to be treated the same as an explicit current one.
    it('treats an empty branch name as no branch name', function()
      local plan = branch.plan_delete('', 'main', false)

      assert.is_false(plan.ok)
      assert.is_truthy(plan.reason:find('current branch', 1, true))
    end)
  end)

  describe('confirm_prompt', function()
    it('names both targets when the remote branch exists', function()
      local prompt = branch.confirm_prompt('feature', true, 'origin')

      assert.is_truthy(prompt:find('feature', 1, true))
      assert.is_truthy(prompt:find('origin', 1, true))
      assert.is_truthy(prompt:find('locally and from', 1, true))
    end)

    it('says the remote is untouched when there is nothing there', function()
      local prompt = branch.confirm_prompt('feature', false, 'origin')

      assert.is_truthy(prompt:find('no counterpart', 1, true))
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
        assert.are.equal('trunk', branch.current_branch())
      end)
    end)

    it('reports a branch whose name contains slashes', function()
      in_repository('feature/nested/name', function()
        assert.are.equal('feature/nested/name', branch.current_branch())
      end)
    end)

    it('returns nil outside a repository', function()
      local previous = vim.fn.getcwd()
      local directory = vim.fn.tempname()

      vim.fn.mkdir(directory, 'p')
      vim.fn.chdir(directory)

      local name = branch.current_branch()

      vim.fn.chdir(previous)

      assert.is_nil(name)
    end)
  end)

  describe('exists_on_remote', function()
    it('is false for a branch that does not exist', function()
      assert.is_false(branch.exists_on_remote('origin', 'a-branch-that-should-never-exist'))
    end)
  end)
end)
