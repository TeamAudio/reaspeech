--[[

  TextInput.lua - TextInput Widget

]]--

Widgets.TextInput = (function()

local TextInput = {}

TextInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or ''

  options.on_change = options.on_change or function() end

  options.on_enter = options.on_enter or function() end

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = TextInput.renderer,
    options = options,
  })

  return o
end

TextInput.simple = function(default_value, label)
  return TextInput.new {
    default = default_value,
    label = label
  }
end

TextInput.renderer = function (self)
  local options = self.options

  if options.label then
    self:render_label()
  end

  local imgui_label = ("##%s"):format(options.label)

  local rv, value = ImGui.InputText(ctx, imgui_label, self:value())

  if ImGui.IsItemDeactivated(ctx) then
    self.options.on_enter()
    self:set(value)
  end

  if rv then
    self.options.on_change(value)
    self:set(value)
  end
end

return TextInput

end)()
