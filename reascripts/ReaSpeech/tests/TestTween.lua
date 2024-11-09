package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('Polo')
require('Storage')
require('source/Logging')

reaper = {
  time_precise = function()
    return 0
  end
}

require('source/Tween')

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

function TestTween:testDocumentation()
  local tween -- an instance of a Tween(...)
      , value -- calling tween() will return the current value

  -- use a predefined tween function

  local start_value = 0
  local end_value = 1
  local duration = 0.2
  local on_end = function()
    -- optionally do something when the tween is done
  end

  tween = Tween.linear(start_value, end_value, duration, on_end)

  value = tween()

  -- or define your own tween function like the module does

  local time_function = function() return 0 end
    -- default: ...or reaper and reaper.time_precise

  local my_linear_tween = Tween(function(t, b, c, d)
    return b + c * t / d
  end, time_function)

  tween = my_linear_tween(0.0, 1.0, 0.2, on_end)

  value = tween()
end

--

os.exit(lu.LuaUnit.run())