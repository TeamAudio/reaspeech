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

  local rv, value = ImGui.InputInt(ctx, imgui_label, self:value())

  if rv and ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set(value)
  end
end

return NumberInput

end)()
