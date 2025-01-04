--[[

  IntervalFunction.lua - Interval functions that run every x seconds or ticks

  Examples:

    IntervalFunction().new(5, function()
      -- run no more often than once every 5 seconds
      -- chill interval to check on states that don't
      -- need to feel so snappy
    end),

    IntervalFunction().new(-15, function ()
      -- run every 15 ticks, ~0.5 seconds
      -- maybe a good interval for updating some states
      -- in a way that feels responsive, like selections
    end)

]]--

IntervalFunction = setmetatable({}, {
  __call = function(self)
    if self._instance then
      return self._instance
    end

    self._instance = self._init()

    return self._instance
  end
})

IntervalFunction._init = function()
  local o = Polo {
    new = function(interval, f)
      return {
        interval = interval,
        f = f,
        last = 0
      }
    end
  }

  function o:react(time)
    if self.interval >= 0 then
      if time - self.last >= self.interval then
        self.f()
        self.last = time
      end
    else
      self.last = self.last - 1

      if self.last < self.interval then
        self.f()
        self.last = 0
      end
    end
  end

  return o
end

