package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

require('main/script_match/metadata_layers/TagsMetadataLayer')

--

TestFindMatchingColumn = {}

function TestFindMatchingColumn:testExactMatch()
  lu.assertEquals(
    TagsMetadataLayer.find_matching_column('character', { 'Line', 'Character', 'Notes' }),
    2)
end

function TestFindMatchingColumn:testCaseInsensitiveAndTrimmed()
  lu.assertEquals(
    TagsMetadataLayer.find_matching_column('character', { 'line', '  CHARACTER  ' }),
    2)
end

function TestFindMatchingColumn:testNoMatch()
  lu.assertNil(TagsMetadataLayer.find_matching_column('emotion', { 'Line', 'Character' }))
end

function TestFindMatchingColumn:testCustomNeverMatches()
  lu.assertNil(TagsMetadataLayer.find_matching_column('custom', { 'Custom Tag' }))
end

function TestFindMatchingColumn:testNilHeaders()
  lu.assertNil(TagsMetadataLayer.find_matching_column('character', nil))
end

--

os.exit(lu.LuaUnit.run())
