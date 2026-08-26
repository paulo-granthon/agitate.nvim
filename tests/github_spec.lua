describe('service.github', function()
  local http = require('agitate.service.http')
  local github = require('agitate.service.github')

  ---Reads one of the captured GitHub responses.
  local function fixture(name)
    local raw = table.concat(vim.fn.readfile('tests/fixtures/' .. name .. '.json'), '\n')

    return raw, vim.json.decode(raw)
  end

  local original_request
  local captured_request

  ---Replaces the transport with one that answers immediately.
  local function respond_with(request_ok, response)
    http.request = function(request, callback)
      captured_request = request
      callback(request_ok, response)
    end
  end

  before_each(function()
    captured_request = nil
    original_request = http.request
  end)

  after_each(function()
    http.request = original_request
  end)

  describe('describe_failure', function()
    it('surfaces both the top level message and the field level reason', function()
      local raw, body = fixture('repo_create_error')
      local message = github.describe_failure('create the repository', { status = 422, body = body, raw = raw })

      assert.is_truthy(message:find('Repository creation failed.', 1, true))
      assert.is_truthy(message:find('name is reserved', 1, true))
      assert.is_truthy(message:find('HTTP 422', 1, true))
    end)

    it('falls back to the raw body when GitHub sends no structured reason', function()
      local message = github.describe_failure('do the thing', { status = 502, body = nil, raw = '<html>bad gateway</html>' })

      assert.is_truthy(message:find('<html>bad gateway</html>', 1, true))
    end)

    it('says so explicitly when there is nothing at all to report', function()
      local message = github.describe_failure('do the thing', { status = 500, body = nil, raw = '' })

      assert.is_truthy(message:find('GitHub gave no reason', 1, true))
    end)
  end)

  describe('call', function()
    it('passes the path, method and body to the transport', function()
      respond_with(true, { status = 200, body = {}, raw = '{}' })

      github.call('token', { path = 'repos/acme/thing', method = 'PATCH', body = { a = 1 } }, 'do it', 200, function() end)

      assert.are.equal('https://api.github.com/repos/acme/thing', captured_request.url)
      assert.are.equal('PATCH', captured_request.method)
      assert.are.same({ a = 1 }, captured_request.body)
      assert.are.equal('token', captured_request.token)
    end)

    it('succeeds only on the expected status', function()
      respond_with(true, { status = 200, body = { ok = true }, raw = '{}' })

      local result_ok
      github.call('token', { path = 'x' }, 'do it', 201, function(value_ok)
        result_ok = value_ok
      end)

      assert.is_false(result_ok)
    end)

    it('hands back the decoded body on the expected status', function()
      respond_with(true, { status = 201, body = { id = 7 }, raw = '{}' })

      local result
      github.call('token', { path = 'x' }, 'do it', 201, function(_, value)
        result = value
      end)

      assert.are.equal(7, result.id)
    end)

    -- A proxy or an outage can answer with HTML on a 200. Reporting that as a
    -- success would hand the caller a nil body to index.
    it('fails when a successful status carries no JSON', function()
      respond_with(true, { status = 200, body = nil, raw = '<html>hello</html>' })

      local result_ok, result
      github.call('token', { path = 'x' }, 'do it', 200, function(value_ok, value)
        result_ok, result = value_ok, value
      end)

      assert.is_false(result_ok)
      assert.is_truthy(result.message:find('expected JSON', 1, true))
    end)

    it('passes a transport failure straight through', function()
      respond_with(false, { message = 'curl exited with code 6' })

      local result_ok, result
      github.call('token', { path = 'x' }, 'do it', 200, function(value_ok, value)
        result_ok, result = value_ok, value
      end)

      assert.is_false(result_ok)
      assert.are.equal('curl exited with code 6', result.message)
    end)
  end)

  describe('is_organization', function()
    it('treats 200 as an organization', function()
      respond_with(true, { status = 200, body = { login = 'acme' }, raw = '{}' })

      local result
      github.is_organization('token', 'acme', function(_, value)
        result = value
      end)

      assert.is_true(result)
    end)

    -- A personal account 404s here. That is the common case, not a failure.
    it('treats 404 as a user rather than an error', function()
      respond_with(true, { status = 404, body = { message = 'Not Found' }, raw = '{}' })

      local lookup_ok, result
      github.is_organization('token', 'octocat', function(value_ok, value)
        lookup_ok, result = value_ok, value
      end)

      assert.is_true(lookup_ok)
      assert.is_false(result)
    end)

    -- Treating a bad token as "not an organization" would silently create the
    -- repository under the wrong owner.
    it('reports a 401 instead of assuming a user', function()
      respond_with(true, { status = 401, body = { message = 'Bad credentials' }, raw = '{}' })

      local lookup_ok, result
      github.is_organization('token', 'acme', function(value_ok, value)
        lookup_ok, result = value_ok, value
      end)

      assert.is_false(lookup_ok)
      assert.is_truthy(result.message:find('Bad credentials', 1, true))
    end)

    -- A proxy or outage page can answer 200 with HTML. Reading that as an
    -- organization would create the repository under `orgs/<name>`.
    it('refuses a 200 that carries no JSON', function()
      respond_with(true, { status = 200, body = nil, raw = '<html>proxy</html>' })

      local lookup_ok, result
      github.is_organization('token', 'acme', function(value_ok, value)
        lookup_ok, result = value_ok, value
      end)

      assert.is_false(lookup_ok)
      assert.is_truthy(result.message:find('expected JSON', 1, true))
    end)

    it('passes a transport failure straight through', function()
      respond_with(false, { message = 'curl exited with code 6' })

      local lookup_ok, result
      github.is_organization('token', 'acme', function(value_ok, value)
        lookup_ok, result = value_ok, value
      end)

      assert.is_false(lookup_ok)
      assert.are.equal('curl exited with code 6', result.message)
    end)
  end)

  describe('create_repository', function()
    it('posts the name and visibility to the given path', function()
      local raw, body = fixture('repo_create_success')
      respond_with(true, { status = 201, body = body, raw = raw })

      github.create_repository('token', { name = 'agitate', is_private = true, path = 'orgs/acme' }, function() end)

      assert.are.equal('POST', captured_request.method)
      assert.are.equal('https://api.github.com/orgs/acme/repos', captured_request.url)
      assert.are.equal('token', captured_request.token)
      assert.are.same({ name = 'agitate', private = true }, captured_request.body)
    end)

    it('returns the created repository on 201', function()
      local raw, body = fixture('repo_create_success')
      respond_with(true, { status = 201, body = body, raw = raw })

      local created_ok, repository
      github.create_repository('token', { name = 'agitate', is_private = false, path = 'user' }, function(value_ok, value)
        created_ok, repository = value_ok, value
      end)

      assert.is_true(created_ok)
      assert.are.equal('https://github.com/paulo-granthon/test_agitate_save_output', repository.html_url)
    end)

    it('reports the GitHub reason on a rejected creation', function()
      local raw, body = fixture('repo_create_error')
      respond_with(true, { status = 422, body = body, raw = raw })

      local created_ok, result
      github.create_repository('token', { name = 'agitate', is_private = false, path = 'user' }, function(value_ok, value)
        created_ok, result = value_ok, value
      end)

      assert.is_false(created_ok)
      assert.is_truthy(result.message:find('name is reserved', 1, true))
    end)

    it('rejects a success that carries no html_url', function()
      respond_with(true, { status = 201, body = { name = 'agitate' }, raw = '{"name":"agitate"}' })

      local created_ok, result
      github.create_repository('token', { name = 'agitate', is_private = false, path = 'user' }, function(value_ok, value)
        created_ok, result = value_ok, value
      end)

      assert.is_false(created_ok)
      assert.is_truthy(result.message:find('no `html_url`', 1, true))
    end)
  end)
  describe('get_gitignore_template', function()
    -- `C++` is a real template name. Unencoded, a name containing `#` would
    -- truncate the path at the fragment and hit the wrong endpoint entirely.
    it('percent encodes the template name in the path', function()
      respond_with(true, { status = 200, body = { source = 'build/' }, raw = '{}' })

      github.get_gitignore_template('token', 'C++', function() end)

      assert.are.equal('https://api.github.com/gitignore/templates/C%2B%2B', captured_request.url)
    end)

    it('names the template unencoded in the failure message', function()
      respond_with(true, { status = 404, body = { message = 'Not Found' }, raw = '{}' })

      local fetch_ok, result
      github.get_gitignore_template('token', 'C++', function(value_ok, value)
        fetch_ok, result = value_ok, value
      end)

      assert.is_false(fetch_ok)
      assert.is_truthy(result.message:find('C++', 1, true))
    end)
  end)
end)
