package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

-- require('mock_reaper')
require('Polo')
require('Storage')
require('source/Logging')
require('source/Tween')

reaper = {
  time_precise = function()
    return 0
  end
}

--

TestTween = {}

function TestTween:testNew()
  local start_value = 0
  local end_value = 1
  local duration = 1
  local tween = Tween.new(start_value, end_value, duration)
end

--

os.exit(lu.LuaUnit.run())