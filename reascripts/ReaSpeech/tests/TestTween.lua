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
  local start_value = 1
  local end_value = 10
  local duration = 1
  local time = 0
  local f = function(t, b, c, d)
    lu.assertEquals(t, 0)
    lu.assertEquals(b, start_value)
    lu.assertEquals(c, end_value - start_value)
    lu.assertEquals(d, duration)
    return "derp"
  end

  local boring_tween = Tween(f, function() return time end)

  local tween = boring_tween(start_value, end_value, duration)

  lu.assertEquals(tween(), "derp")
end

function TestTween:testCallback()
  local start_value = 1
  local end_value = 10
  local duration = 1
  local time = 0
  local f = function(t, b, c, d)
    return b + c * t / d
  end

  local boring_tween = Tween(f, function() return time end)

  local callback_called = false

  local tween = boring_tween(start_value, end_value, duration, function()
    callback_called = true
  end)

  lu.assertEquals(callback_called, false)
  lu.assertEquals(tween(), 1)
  lu.assertEquals(callback_called, false)
  time = 1
  lu.assertEquals(tween(), 10)
  lu.assertEquals(callback_called, true)
end

--

os.exit(lu.LuaUnit.run())