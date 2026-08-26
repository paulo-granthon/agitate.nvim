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

  describe('get_all', function()
    ---Answers each request with the next canned page.
    local function respond_with_pages(pages)
      local seen = 0

      http.request = function(request, callback)
        seen = seen + 1
        captured_request = request
        callback(true, { status = 200, body = pages[seen] or {}, raw = '[]' })
      end

      return function()
        return seen
      end
    end

    it('returns a single short page as is', function()
      respond_with_pages({ { { id = 1 }, { id = 2 } } })

      local result
      github.get_all('token', 'repos/acme/thing/issues', 'list', function(_, value)
        result = value
      end)

      assert.are.equal(2, #result)
    end)

    -- A full page is how GitHub signals there may be more; stopping there is
    -- what silently truncated every list.
    it('keeps paging while pages come back full', function()
      local full = {}
      for index = 1, 100 do
        full[index] = { id = index }
      end

      local requests = respond_with_pages({ full, { { id = 101 } } })

      local result
      github.get_all('token', 'repos/acme/thing/issues', 'list', function(_, value)
        result = value
      end)

      assert.are.equal(2, requests())
      assert.are.equal(101, #result)
    end)

    it('appends the page parameters with & when the path already has a query', function()
      respond_with_pages({ {} })

      github.get_all('token', 'repos/acme/thing/issues?state=open', 'list', function() end)

      assert.is_truthy(captured_request.url:find('state=open&per_page=100&page=1', 1, true))
    end)

    it('appends them with ? when the path has no query', function()
      respond_with_pages({ {} })

      github.get_all('token', 'repos/acme/thing/issues', 'list', function() end)

      assert.is_truthy(captured_request.url:find('issues?per_page=100&page=1', 1, true))
    end)

    it('passes a failure through instead of returning a partial list', function()
      respond_with(false, { message = 'curl exited with code 6' })

      local list_ok, result
      github.get_all('token', 'repos/acme/thing/issues', 'list', function(value_ok, value)
        list_ok, result = value_ok, value
      end)

      assert.is_false(list_ok)
      assert.are.equal('curl exited with code 6', result.message)
    end)
  end)

  describe('list_comments', function()
    -- `core.pr` called this and it did not exist on that branch, so viewing a
    -- pull request errored at runtime. It lives here because both the issue
    -- and pull request features need it.
    it('reads the issues comments endpoint for either kind', function()
      respond_with(true, { status = 200, body = {}, raw = '[]' })

      github.list_comments('token', 'acme', 'thing', 9, function() end)

      assert.is_truthy(captured_request.url:find('repos/acme/thing/issues/9/comments', 1, true))
      assert.are.equal('token', captured_request.token)
    end)
  end)

  describe('list_issues', function()
    -- GitHub's issues endpoint also returns pull requests. Any entry with a
    -- `pull_request` key is one, and an issue list showing them would be wrong.
    it('filters out pull requests', function()
      respond_with(true, {
        status = 200,
        raw = '[]',
        body = {
          { number = 1, title = 'A real issue' },
          { number = 2, title = 'A pull request', pull_request = { url = 'https://api.github.com/x' } },
          { number = 3, title = 'Another issue' },
        },
      })

      local result
      github.list_issues('token', 'acme', 'thing', 'open', function(_, value)
        result = value
      end)

      assert.are.equal(2, #result)
      assert.are.equal(1, result[1].number)
      assert.are.equal(3, result[2].number)
    end)

    it('requests the given state and pages the results', function()
      respond_with(true, { status = 200, body = {}, raw = '[]' })

      github.list_issues('token', 'acme', 'thing', 'closed', function() end)

      assert.is_truthy(captured_request.url:find('state=closed', 1, true))
      assert.is_truthy(captured_request.url:find('repos/acme/thing/issues', 1, true))
      assert.is_truthy(captured_request.url:find('per_page=100&page=1', 1, true))
    end)

    it('passes a failure through without filtering it', function()
      respond_with(true, { status = 404, body = { message = 'Not Found' }, raw = '{}' })

      local list_ok, result
      github.list_issues('token', 'acme', 'thing', 'open', function(value_ok, value)
        list_ok, result = value_ok, value
      end)

      assert.is_false(list_ok)
      assert.is_truthy(result.message:find('Not Found', 1, true))
    end)
  end)

  describe('create_issue', function()
    it('posts the title and body', function()
      respond_with(true, { status = 201, body = { number = 5 }, raw = '{}' })

      github.create_issue('token', 'acme', 'thing', { title = 'Fix it', body = 'Please.' }, function() end)

      assert.are.equal('POST', captured_request.method)
      assert.are.equal('https://api.github.com/repos/acme/thing/issues', captured_request.url)
      assert.are.same({ title = 'Fix it', body = 'Please.' }, captured_request.body)
    end)

    -- The caller announces the new issue by concatenating both of these, so a
    -- success missing either would crash while reporting itself.
    it('rejects a success that carries no number or html_url', function()
      respond_with(true, { status = 201, body = { title = 'Fix it' }, raw = '{}' })

      local created_ok, result
      github.create_issue('token', 'acme', 'thing', { title = 'Fix it', body = '' }, function(value_ok, value)
        created_ok, result = value_ok, value
      end)

      assert.is_false(created_ok)
      assert.is_truthy(result.message:find('no `number` or `html_url`', 1, true))
    end)
  end)

  describe('set_issue_state', function()
    it('patches the state', function()
      respond_with(true, { status = 200, body = {}, raw = '{}' })

      github.set_issue_state('token', 'acme', 'thing', 7, 'closed', function() end)

      assert.are.equal('PATCH', captured_request.method)
      assert.are.equal('https://api.github.com/repos/acme/thing/issues/7', captured_request.url)
      assert.are.same({ state = 'closed' }, captured_request.body)
    end)
  end)

  describe('create_comment', function()
    -- GitHub models a pull request as an issue for commenting, which is why
    -- the path says `issues` even for a pull request number.
    it('posts to the issues comments endpoint', function()
      respond_with(true, { status = 201, body = {}, raw = '{}' })

      github.create_comment('token', 'acme', 'thing', 9, 'Looks good.', function() end)

      assert.are.equal('POST', captured_request.method)
      assert.are.equal('https://api.github.com/repos/acme/thing/issues/9/comments', captured_request.url)
      assert.are.same({ body = 'Looks good.' }, captured_request.body)
    end)
  end)
end)
