--[[

  TextInput.lua - TextInput Widget

]]--

local TextInput = {}
Widgets.TextInput = TextInput

TextInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or ''

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

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local rv, value = ImGui.InputText(ctx, imgui_label, self:value())

  if rv then
    self:set(value)
  end
end
