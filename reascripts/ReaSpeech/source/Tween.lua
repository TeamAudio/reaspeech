--[[

  Tween.lua - basic tweens for animation

  Usage:
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
]]--

Tween = {
  __call = function(_, f, time_f)
    time_f = time_f or reaper and reaper.time_precise
    local tween_definition = { f = f }
    setmetatable(tween_definition, tween_definition)

    tween_definition.__call = function(_self, start_value, end_value, duration, on_end)
      local t = {}
      t.start_value = start_value
      t.end_value = end_value
      t.duration = duration
      t.change = end_value - start_value
      t.start_time = time_f()
      t.on_end = on_end or function() end

      t.__call = function(self)
        local time = time_f()

        if time >= t.start_time + t.duration then
          if t.on_end then
            self.on_end()
            self.on_end = function() end
          end

          return self.end_value
        else
          return tween_definition.f(
            time - self.start_time,
            self.start_value,
            self.end_value - self.start_value,
            self.duration
          )
        end
      end

      setmetatable(t, t)
      return t
    end

    return tween_definition
  end
}
setmetatable(Tween, Tween)

Tween.linear = Tween(function(t, b, c, d)
  return b + c * t / d
end)

Tween.inQuad = Tween(function(t, b, c, d)
  t = t / d
  return c * t ^ 2 + b
end)

Tween.inCubic = Tween(function(t, b, c, d)
  t = t / d
  return c * t ^ 3 + b
end)
