--[[

  Tween.lua - basic tweens for animation

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
        self:debug('tween called @ ' .. time)

        if time >= t.start_time + t.duration then
          self:debug('tween done')
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
      Logging.init(t, 'Tween')
      return t
    end

    return tween_definition
  end
}
setmetatable(Tween, Tween)

Tween.linear = Tween(function(t, b, c, d)
  return b + c * t / d
end)
