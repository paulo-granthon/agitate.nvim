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
end)
