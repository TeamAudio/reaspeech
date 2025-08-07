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

  local rv, value = ImGui.InputInt(Ctx(), imgui_label, current_value)

  local in_bounds = (options.min == nil or value >= options.min) and (options.max == nil or value <= options.max)

  if rv and in_bounds then
    self:set(value)
  end
end

return NumberInput

end)()
