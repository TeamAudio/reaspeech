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
  if column.width < self.width_threshold then
    label = self.label_short
  end

  local rv, value = ImGui.Checkbox(self.ctx, label, self:value())

  if rv then
    self._value = value
  end
end