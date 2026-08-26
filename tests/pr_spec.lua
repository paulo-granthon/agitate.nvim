describe('core.pr', function()
  local pr = require('agitate.core.pr')

  describe('plan_merge', function()
    ---A pull request GitHub considers ready to merge.
    local function clean(overrides)
      return vim.tbl_extend('force', {
        state = 'open',
        merged = false,
        mergeable = true,
        mergeable_state = 'clean',
      }, overrides or {})
    end

    it('allows a clean, open, mergeable pull request', function()
      local decision = pr._plan_merge(clean())

      assert.is_true(decision.allowed)
      assert.is_nil(decision.warning)
    end)

    it('refuses one that is already merged', function()
      local decision = pr._plan_merge(clean({ merged = true }))

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('already merged', 1, true))
    end)

    it('refuses one that is closed', function()
      local decision = pr._plan_merge(clean({ state = 'closed' }))

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('closed', 1, true))
    end)

    it('refuses a conflicting branch and says so', function()
      local decision = pr._plan_merge(clean({ mergeable_state = 'dirty', mergeable = false }))

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('conflicts', 1, true))
    end)

    it('refuses when a required review or check is missing', function()
      local decision = pr._plan_merge(clean({ mergeable_state = 'blocked' }))

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('required review', 1, true))
    end)

    it('refuses a draft', function()
      assert.is_false(pr._plan_merge(clean({ mergeable_state = 'draft' })).allowed)
    end)

    it('refuses a branch that is behind its base', function()
      assert.is_false(pr._plan_merge(clean({ mergeable_state = 'behind' })).allowed)
    end)

    it('refuses when GitHub reports it as not mergeable', function()
      local decision = pr._plan_merge(clean({ mergeable = false, mergeable_state = 'unknown' }))

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('not mergeable', 1, true))
    end)

    -- GitHub computes `mergeable` asynchronously and returns nil until it is
    -- done. Merging on an unknown is how a surprise conflict gets forced in.
    it('refuses while GitHub is still computing mergeability', function()
      local pull = clean()
      pull.mergeable = nil

      local decision = pr._plan_merge(pull)

      assert.is_false(decision.allowed)
      assert.is_truthy(decision.reason:find('not finished checking', 1, true))
    end)

    -- Failing checks on an otherwise mergeable branch is a judgement call, not
    -- a blocker, so it warns rather than refusing.
    it('allows an unstable pull request but warns about the checks', function()
      local decision = pr._plan_merge(clean({ mergeable_state = 'unstable' }))

      assert.is_true(decision.allowed)
      assert.is_truthy(decision.warning:find('checks', 1, true))
    end)

    it('allows one whose repository has hooks', function()
      assert.is_true(pr._plan_merge(clean({ mergeable_state = 'has_hooks' })).allowed)
    end)
  end)
end)
