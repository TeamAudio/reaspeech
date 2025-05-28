--[[

  ReaSpeechWidgets.lua - collection of common widgets that ReaSpeech uses

]]--

ReaSpeechWidget = Polo {}

function ReaSpeechWidget:init()
  if not self.state then
    assert(self.default ~= nil, "default value not provided")
    self.state = Storage.memory(self.default)
  end
  assert(self.renderer, "renderer not provided")
  self.widget_id = self.widget_id or reaper.genGuid("")
  self.on_set = self.options and self.options.on_set or function() end
end

function ReaSpeechWidget:render(...)
  ImGui.PushID(Ctx(), self.widget_id)
  local args = ...
  Trap(function()
    self.renderer(self, args)
  end)
  ImGui.PopID(Ctx())
end

function ReaSpeechWidget:render_help_icon()
  local options = self.options
  local size = Fonts.size:get()
  Widgets.icon(Icons.info, '##help-text', size, size, options.help_text, 0xffffffa0, 0xffffffff)
end

function ReaSpeechWidget:render_label(label)
  local options = self.options
  label = label or options.label

  ImGui.Text(Ctx(), label)

  if label ~= '' and options.help_text then
    ImGui.SameLine(Ctx())
    self:render_help_icon()
  end

  ImGui.Dummy(Ctx(), 0, 0)
end

function ReaSpeechWidget:value()
  return self.state:get()
end

function ReaSpeechWidget:set(value)
  self.state:set(value)
  if self.on_set then self:on_set() end
end
