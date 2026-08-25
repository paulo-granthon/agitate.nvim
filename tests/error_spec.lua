describe('error', function()
  local agitate_error = require('agitate.error')

  local original_notify
  local notifications

  before_each(function()
    notifications = {}
    original_notify = vim.notify
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end
  end)

  after_each(function()
    vim.notify = original_notify
  end)

  describe('describe', function()
    it('resolves a string to itself', function()
      assert.are.equal('boom', agitate_error.describe('boom'))
    end)

    it('resolves an AgitateError to its message', function()
      assert.are.equal('boom', agitate_error.describe({ message = 'boom' }))
    end)

    it('joins a list of errors with newlines', function()
      assert.are.equal('first\nsecond', agitate_error.describe({ { message = 'first' }, 'second' }))
    end)

    it('returns nil when there is no message to resolve', function()
      assert.is_nil(agitate_error.describe({}))
      assert.is_nil(agitate_error.describe(42))
      assert.is_nil(agitate_error.describe(nil))
    end)
  end)

  describe('throw', function()
    it('reports a string error at ERROR level', function()
      agitate_error.throw('boom')

      assert.are.equal(1, #notifications)
      assert.is_truthy(notifications[1].message:find('boom', 1, true))
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
    end)

    it('reports the message of an AgitateError', function()
      agitate_error.throw({ message = 'no token' })

      assert.is_truthy(notifications[1].message:find('no token', 1, true))
    end)

    -- Regression: `throw` used to fall through to `throw(unhandled(...))`,
    -- and `unhandled` returns a table, so any messageless value recursed
    -- until the stack overflowed.
    it('falls back to the unhandled message without recursing', function()
      agitate_error.throw({})

      assert.are.equal(1, #notifications)
      assert.is_truthy(notifications[1].message:find('Unhandled error at', 1, true))
    end)

    it('does not recurse on a value that is neither string nor table', function()
      agitate_error.throw(42)

      assert.are.equal(1, #notifications)
      assert.is_truthy(notifications[1].message:find('Unhandled error at', 1, true))
    end)
  end)
end)
