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
    -- Agitate's own repository is a git checkout, so this exercises the real
    -- command rather than a stub.
    it('reports a branch name inside a repository', function()
      local name = branch.current_branch()

      assert.is_string(name)
      assert.is_true(#name > 0)
      assert.are_not.equal('HEAD', name)
    end)
  end)

  describe('exists_on_remote', function()
    it('is false for a branch that does not exist', function()
      assert.is_false(branch.exists_on_remote('origin', 'a-branch-that-should-never-exist'))
    end)
  end)
end)
