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

require('main/script_match/SessionStatus')

--

TestIsCurated = {}

function TestIsCurated:testAcceptedIsCurated()
  lu.assertIsTrue(SessionStatus.is_curated({ total = 3, accepted = 1, rejected = 0, pending = 2 }))
end

function TestIsCurated:testAllRejectedIsCurated()
  lu.assertIsTrue(SessionStatus.is_curated({ total = 2, accepted = 0, rejected = 2, pending = 0 }))
end

function TestIsCurated:testPendingIsNotCurated()
  lu.assertIsFalse(SessionStatus.is_curated({ total = 2, accepted = 0, rejected = 1, pending = 1 }))
end

-- A roll that found nothing was never judged by anyone: the old
-- vacuous pending == 0 counted it as curated (green check, inflated
-- group tallies)
function TestIsCurated:testZeroSuggestionsIsNotCurated()
  lu.assertIsFalse(SessionStatus.is_curated({ total = 0, accepted = 0, rejected = 0, pending = 0 }))
end

--

os.exit(lu.LuaUnit.run())
