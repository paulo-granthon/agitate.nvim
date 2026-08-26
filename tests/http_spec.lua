describe('service.http', function()
  local http = require('agitate.service.http')

  describe('_build_config', function()
    it('always asks curl to be silent, show errors and follow redirects', function()
      local config = http._build_config(nil)

      assert.is_truthy(config:find('silent', 1, true))
      assert.is_truthy(config:find('show-error', 1, true))
      assert.is_truthy(config:find('location', 1, true))
    end)

    it('pins the API version and asks for the GitHub media type', function()
      local config = http._build_config(nil)

      assert.is_truthy(config:find('X-GitHub-Api-Version: 2022-11-28', 1, true))
      assert.is_truthy(config:find('Accept: application/vnd.github+json', 1, true))
    end)

    it('sends the token as a Bearer credential', function()
      assert.is_truthy(http._build_config('ghp_secret'):find('header = "Authorization: Bearer ghp_secret"', 1, true))
    end)

    it('omits the authorization header entirely when there is no token', function()
      assert.is_nil(http._build_config(nil):find('Authorization', 1, true))
    end)

    it('escapes quotes and backslashes so a token cannot break out of the entry', function()
      local config = http._build_config('a"b\\c')

      assert.is_truthy(config:find('header = "Authorization: Bearer a\\"b\\\\c"', 1, true))
    end)
  end)

  describe('_build_argv', function()
    -- The token must never reach argv: it is readable there through
    -- /proc/<pid>/cmdline by anything running as the same user.
    it('keeps the token out of the argument vector', function()
      local argv = http._build_argv({ url = 'https://example.com', token = 'ghp_secret' })

      assert.is_nil(table.concat(argv, ' '):find('ghp_secret', 1, true))
    end)

    it('reads its configuration from stdin', function()
      local argv = http._build_argv({ url = 'https://example.com' })

      assert.are.equal('curl', argv[1])
      assert.are.equal('--config', argv[2])
      assert.are.equal('-', argv[3])
    end)

    it('defaults to GET', function()
      local argv = http._build_argv({ url = 'https://example.com' })
      local index = vim.fn.index(argv, '--request')

      assert.are.equal('GET', argv[index + 2])
    end)

    it('uses the requested method', function()
      local argv = http._build_argv({ url = 'https://example.com', method = 'PATCH' })
      local index = vim.fn.index(argv, '--request')

      assert.are.equal('PATCH', argv[index + 2])
    end)

    it('appends the status code to the body on its own line', function()
      local argv = http._build_argv({ url = 'https://example.com' })
      local index = vim.fn.index(argv, '--write-out')

      assert.are.equal('\n%{http_code}', argv[index + 2])
    end)

    it('encodes a body as JSON', function()
      local argv = http._build_argv({ url = 'https://example.com', method = 'POST', body = { name = 'repo' } })
      local index = vim.fn.index(argv, '--data-binary')

      assert.is_true(index >= 0)
      assert.are.same({ name = 'repo' }, vim.json.decode(argv[index + 2]))
    end)

    it('sends no body when none was given', function()
      assert.are.equal(-1, vim.fn.index(http._build_argv({ url = 'https://example.com' }), '--data-binary'))
    end)

    it('puts the url last', function()
      local argv = http._build_argv({ url = 'https://example.com', method = 'POST', body = { a = 1 } })

      assert.are.equal('https://example.com', argv[#argv])
    end)
  end)

  describe('_split_response', function()
    it('separates the trailing status code from the body', function()
      local body, status = http._split_response('{"a":1}\n201')

      assert.are.equal('{"a":1}', body)
      assert.are.equal(201, status)
    end)

    it('keeps newlines inside a multi line body', function()
      local body, status = http._split_response('{\n  "a": 1\n}\n200')

      assert.are.equal('{\n  "a": 1\n}', body)
      assert.are.equal(200, status)
    end)

    it('reports a nil status when the trailing line is not a number', function()
      local _, status = http._split_response('total nonsense')

      assert.is_nil(status)
    end)

    it('handles an empty body', function()
      local body, status = http._split_response('\n204')

      assert.are.equal('', body)
      assert.are.equal(204, status)
    end)
  end)

  describe('request', function()
    ---Runs an async request to completion and returns what the callback got.
    local function await(request)
      local done, captured = false, nil

      http.request(request, function(request_ok, result)
        captured = { ok = request_ok, result = result }
        done = true
      end)

      vim.wait(10000, function()
        return done
      end)

      return captured
    end

    -- Exercises the real curl process end to end, without touching the
    -- network, by reading a local file through curl's file:// support.
    it('runs curl and decodes a JSON body', function()
      local path = vim.fn.tempname()
      vim.fn.writefile({ '{"name":"agitate","private":true}' }, path)

      local captured = await({ url = 'file://' .. path })

      assert.is_true(captured.ok)
      assert.are.equal('agitate', captured.result.body.name)
      assert.is_true(captured.result.body.private)
    end)

    it('keeps the raw body available when it is not JSON', function()
      local path = vim.fn.tempname()
      vim.fn.writefile({ 'not json at all' }, path)

      local captured = await({ url = 'file://' .. path })

      assert.is_true(captured.ok)
      assert.is_nil(captured.result.body)
      -- `writefile` terminates the line, so the trailing newline is part of
      -- the resource. The body is returned exactly as served.
      assert.are.equal('not json at all\n', captured.result.raw)
    end)

    it('reports a failure when curl cannot complete the request', function()
      local captured = await({ url = 'file:///definitely/not/here/agitate' })

      assert.is_false(captured.ok)
      assert.is_truthy(captured.result.message:find('curl exited with code', 1, true))
    end)

    it('invokes the callback on the main loop, where the vim API is usable', function()
      local path = vim.fn.tempname()
      vim.fn.writefile({ '{}' }, path)

      local done, api_ok = false, nil

      http.request({ url = 'file://' .. path }, function()
        -- Fails inside a fast event context, which is exactly what
        -- scheduling the callback is meant to prevent.
        api_ok = pcall(vim.api.nvim_get_current_buf)
        done = true
      end)

      vim.wait(10000, function()
        return done
      end)

      assert.is_true(api_ok)
    end)
  end)
end)
