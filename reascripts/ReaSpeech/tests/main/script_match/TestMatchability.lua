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

require('main/script_match/curation/matchers/TextNormalizer')
require('main/script_match/curation/matchers/FuzzyWordMatcher')
require('main/script_match/curation/Matchability')

--

TestMatchability = {}

-- Classes mirror the matcher's own view: same stripping, same
-- tokenizer, same short threshold

function TestMatchability:testDirectionOnlyLinesAreNonVerbal()
  lu.assertEquals(Matchability.classify('[Shrieks.]').class, 'non_verbal')
  lu.assertEquals(Matchability.classify('(gasps)').class, 'non_verbal')
  lu.assertEquals(Matchability.classify('{With a sigh}').class, 'non_verbal')
  lu.assertEquals(Matchability.classify('').class, 'non_verbal')
  lu.assertEquals(Matchability.classify(nil).class, 'non_verbal')
end

function TestMatchability:testShortLines()
  lu.assertEquals(Matchability.classify('Ow!').class, 'short')
  lu.assertEquals(Matchability.classify('Get down now!').class, 'short')
end

function TestMatchability:testDirectionsDoNotCountTowardLength()
  -- The spoken part is what matters: two words plus a direction is
  -- still short
  lu.assertEquals(Matchability.classify('[Whispering.] Get down.').class, 'short')
end

function TestMatchability:testNormalLinesAreText()
  local verdict = Matchability.classify('And who taught you to juggle?')
  lu.assertEquals(verdict.class, 'text')
  lu.assertNil(verdict.reason)
end

function TestMatchability:testShortThresholdTracksTheMatcher()
  -- Exactly at the matcher's short threshold = short; one past = text
  local at_limit = {}
  for i = 1, FuzzyWordMatcher.SHORT_NEEDLE_TOKENS do
    at_limit[i] = 'word' .. i
  end
  lu.assertEquals(Matchability.classify(table.concat(at_limit, ' ')).class, 'short')
  lu.assertEquals(
    Matchability.classify(table.concat(at_limit, ' ') .. ' extra').class, 'text')
end

--

os.exit(lu.LuaUnit.run())
