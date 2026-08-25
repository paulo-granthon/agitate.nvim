describe('core.file', function()
  local file = require('agitate.core.file')

  describe('apply_license_placeholders', function()
    -- GitHub returns the template verbatim. Writing it out unchanged produces
    -- a LICENSE that names nobody while looking finished.
    it('fills the bracket style placeholders', function()
      local body = file.apply_license_placeholders('Copyright (c) [year] [fullname]', 2026, 'Paulo Granthon')

      assert.are.equal('Copyright (c) 2026 Paulo Granthon', body)
    end)

    it('fills the angle style placeholders', function()
      local body = file.apply_license_placeholders('Copyright (C) <year> <name of author>', 2026, 'Paulo Granthon')

      assert.are.equal('Copyright (C) 2026 Paulo Granthon', body)
    end)

    it('replaces every occurrence', function()
      local body = file.apply_license_placeholders('[year] and [year]', 2026, 'anyone')

      assert.are.equal('2026 and 2026', body)
    end)

    it('accepts a year given as a string', function()
      assert.are.equal('2026', file.apply_license_placeholders('[year]', '2026', 'anyone'))
    end)

    it('leaves a body with no placeholders untouched', function()
      assert.are.equal('All rights reserved.', file.apply_license_placeholders('All rights reserved.', 2026, 'anyone'))
    end)

    -- An author containing `%` would otherwise be read as a gsub capture
    -- reference and corrupt the output.
    it('does not treat the author as a replacement pattern', function()
      assert.are.equal('100% Free', file.apply_license_placeholders('[fullname] Free', 2026, '100%'))
    end)
  end)

  describe('funding_content', function()
    it('lists the username under the github platform', function()
      local lines = file.funding_content('octocat')

      assert.are.equal('github: [octocat]', lines[#lines])
    end)

    it('returns a list of lines rather than one blob', function()
      assert.is_true(#file.funding_content('octocat') > 1)
    end)
  end)
end)
