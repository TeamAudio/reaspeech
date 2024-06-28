--[[

ReaSpeechWidgets.lua - collection of common widgets that ReaSpeech uses

]]--

ReaSpeechWidget = Polo {
}

function ReaSpeechWidget:init()
  assert(self.default ~= nil, "default value not provided")
  assert(self.renderer, "renderer not provided")
  self.ctx = self.ctx or ctx
end

function ReaSpeechWidget:render(...)
  self.renderer(self, ...)
end

function ReaSpeechWidget:value()
  return self._value
end

ReaSpeechCheckbox = {}
ReaSpeechCheckbox.new = function (default_value, label_long, label_short, width_threshold)
  local o = ReaSpeechWidget.new({
    default = default_value,
    renderer = ReaSpeechCheckbox.renderer
  })

  o.label_long = label_long
  o.label_short = label_short
  o.width_threshold = width_threshold
  o._value = o.default
  return o
end

ReaSpeechCheckbox.renderer = function (self, column)
  local label = self.label_long

  if column and column.width < self.width_threshold then
    label = self.label_short
  end

  local rv, value = ImGui.Checkbox(self.ctx, label, self:value())

  if rv then
    self._value = value
  end
end

ReaSpeechTextInput = {}
ReaSpeechTextInput.new = function (default_value, label, hint)
  local o = ReaSpeechWidget.new({
    default = default_value,
    renderer = ReaSpeechTextInput.renderer
  })

  o.label = label
  o.hint = hint
  o._value = o.default
  return o
end

ReaSpeechTextInput.renderer = function (self)
  ImGui.Text(ctx, self.label)
  ImGui.Dummy(ctx, 0, 0)

  local imgui_label = ("##%s"):format(self.label)

  local rv, value
  if self.hint then
    rv, value = ImGui.InputTextWithHint(self.ctx, imgui_label, self:value())
  else
    rv, value = ImGui.InputText(self.ctx, imgui_label, self:value())
  end

  if rv then
    self._value = value
  end
end