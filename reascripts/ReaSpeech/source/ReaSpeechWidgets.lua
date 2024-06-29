--[[

  ReaSpeechWidgets.lua - collection of common widgets that ReaSpeech uses

]]--

ReaSpeechWidget = Polo {
}

function ReaSpeechWidget:init()
  assert(self.default ~= nil, "default value not provided")
  assert(self.renderer, "renderer not provided")
  self.ctx = self.ctx or ctx
  self.on_set = nil
end

function ReaSpeechWidget:render(...)
  self.renderer(self, ...)
end

function ReaSpeechWidget:value()
  return self._value
end

function ReaSpeechWidget:set(value)
  self._value = value
  if self.on_set then self:on_set() end
end

-- Widget Implementations

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
    self:set(value)
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
  ImGui.Text(self.ctx, self.label)
  ImGui.Dummy(self.ctx, 0, 0)

  local imgui_label = ("##%s"):format(self.label)

  local rv, value
  if self.hint then
    rv, value = ImGui.InputTextWithHint(self.ctx, imgui_label, self:value())
  else
    rv, value = ImGui.InputText(self.ctx, imgui_label, self:value())
  end

  if rv then
    self:set(value)
  end
end

ReaSpeechCombo = {}

ReaSpeechCombo.new = function (default_value, label, items, item_labels)
  local o = ReaSpeechWidget.new({
    default = default_value,
    renderer = ReaSpeechCombo.renderer
  })

  o.label = label
  o.items = items
  o.item_labels = item_labels
  o._value = o.default
  return o
end

ReaSpeechCombo.renderer = function (self)
  ImGui.Text(self.ctx, self.label)
  ImGui.Dummy(self.ctx, 0, 0)

  local imgui_label = ("##%s"):format(self.label)

  if ImGui.BeginCombo(self.ctx, imgui_label, self.item_labels[self:value()]) then
    app:trap(function()
      for _, item in pairs(self.items) do
        local is_selected = (item == self:value())
        if ImGui.Selectable(self.ctx, self.item_labels[item], is_selected) then
          self:set(item)
        end
      end
    end)
    ImGui.EndCombo(self.ctx)
  end
end

ReaSpeechTabBar = {}

ReaSpeechTabBar.new = function (default_value, labels)
  local o = ReaSpeechWidget.new({
    default = default_value,
    renderer = ReaSpeechTabBar.renderer
  })

  o.labels = labels
  o._value = o.default
  return o
end

ReaSpeechTabBar.renderer = function (self)
  if ImGui.BeginTabBar(self.ctx, 'TabBar') then
    for _, tab in pairs(self.labels) do
      if ImGui.BeginTabItem(self.ctx, tab.label) then
        app:trap(function()
          self:set(tab.key)
        end)
        ImGui.EndTabItem(self.ctx)
      end
    end
    ImGui.EndTabBar(self.ctx)
  end
end

ReaSpeechTabBar.tab = function(key, label)
  return {
    key = key,
    label = label
  }
end

ReaSpeechButtonBar = {}

ReaSpeechButtonBar.new = function (default_value, label, buttons, styles)
  local o = ReaSpeechWidget.new({
    default = default_value,
    renderer = ReaSpeechButtonBar.renderer
  })

  o.label = label
  o.buttons = buttons
  o._value = o.default

  styles = styles or {}

  local with_button_color = function (selected, f)
    if selected then
      ImGui.PushStyleColor(o.ctx, ImGui.Col_Button(), Theme.colors.dark_gray_translucent)
      app:trap(f)
      ImGui.PopStyleColor(o.ctx)
    else
      f()
    end
  end

  o.layout = ColumnLayout.new {
    column_padding = styles.column_padding or 0,
    margin_bottom = styles.margin_bottom or 0,
    margin_left = styles.margin_left or 0,
    margin_right = styles.margin_right or 0,
    num_columns = #o.buttons,

    render_column = function (column)
      local bar_label = column.num == 1 and o.label or ""
      ImGui.Text(o.ctx, bar_label)
      ImGui.Dummy(o.ctx, 0, 0)

      local button_label, model_name = table.unpack(o.buttons[column.num])
      with_button_color(o:value() == model_name, function ()
        if ImGui.Button(o.ctx, button_label, column.width) then
          o:set(model_name)
        end
      end)
    end
  }
  return o
end

ReaSpeechButtonBar.renderer = function (self)
  self.layout:render()
end