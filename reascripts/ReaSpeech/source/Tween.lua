--[[

  Tween.lua - basic tweens for animation

]]--

Tween = Polo {
  new = function(start_value, end_value, duration)
    local self = {}
    self.start_value = start_value
    self.end_value = end_value
    self.duration = duration
    return self
  end,
}

function Tween:init()
  self.current_value = self.start_value
  self:reset()
end

function Tween:update()
  local current_time = reaper.time_precise()

  if self:is_done(current_time) then return end

  local progress = (current_time - self.start_time) / (self.end_time - self.start_time)
  self.current_value = self.start_value + (self.end_value - self.start_value) * progress
end

function Tween:reset()
  self.start_time = reaper.time_precise()
  self.end_time = self.start_time + self.duration
end

function Tween:is_done(current_time)
  current_time = current_time or reaper.time_precise()
  return current_time >= self.end_time
end

function Tween:value()
  self:update()
  if self:is_done() then
    return self.end_value
  else
    return self.current_value
  end
end

function Tween.linear(start, end_, duration)
  local t = Tween.new(start, end_, duration)

  return function() return { t:value() } end
end
