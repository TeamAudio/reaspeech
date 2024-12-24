--[[

  Checkbox.lua - Checkbox widget

]]--

local Checkbox = {}
Widgets.Checkbox = Checkbox

Checkbox.new = function (options)
  options = options or {
    label_long = nil,
    label_short = nil,
    width_threshold = nil,
  }
  options.default = options.default or false

  options.disabled_if = options.disabled_if or function() return false end

  options.changed_handler = options.changed_handler or function(_) end

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = Checkbox.renderer,
    options = options,
  })

  options.changed_handler(o:value())

  return o
end

Checkbox.simple = function(default_value, label, changed_handler)
  return Checkbox.new {
    default = default_value,
    label_long = label,
    label_short = label,
    width_threshold = 0,
    changed_handler = changed_handler or function() end,
  }
end

Checkbox.renderer = function (self, column)
  local disable_if = ReaUtil.disabler(ctx)
  local options = self.options
  local label = options.label_long

  if column and column.width < options.width_threshold then
    label = options.label_short
  end

  disable_if(self.options.disabled_if(), function()
    local rv, value = ImGui.Checkbox(ctx, label, self:value())

    if options.help_text then
      ImGui.SameLine(ctx)
      ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + 7)
      self:render_help_icon()
    end

    if rv then
      self:set(value)
      options.changed_handler(value)
    end
  end)
end

