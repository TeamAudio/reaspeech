--[[

  NumberInput.lua - Number input widget

]]--

Widgets.NumberInput = (function()

local NumberInput = {}

NumberInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or 0
  options.min = options.min or nil
  options.max = options.max or nil
  -- InputDouble only draws the +/- step buttons when a step is given
  -- (InputInt defaults step=1, InputDouble defaults step=0)
  options.step = options.step or nil
  options.step_fast = options.step_fast or nil
  options.format = options.format or nil
  options.whole = options.whole or nil

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = NumberInput.renderer,
    options = options,
  })

  return o
end

NumberInput.simple = function(default_value, label)
  return NumberInput.new {
    default = default_value,
    label = label
  }
end

NumberInput.renderer = function (self)
  local options = self.options

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local current_value = self:value()

  local rv, value = ImGui.InputDouble(Ctx(), imgui_label, current_value,
    options.step, options.step_fast, options.format)

  local in_bounds = (options.min == nil or value >= options.min) and (options.max == nil or value <= options.max)

  if rv and in_bounds then
    -- InputDouble accepts fractional typed input regardless of step and
    -- format, so integer settings must round the committed value
    -- (half away from zero, so negatives round symmetrically)
    if options.whole then
      if value >= 0 then
        value = math.floor(value + 0.5)
      else
        value = math.ceil(value - 0.5)
      end
    end
    self:set(value)
  end
end

return NumberInput

end)()
