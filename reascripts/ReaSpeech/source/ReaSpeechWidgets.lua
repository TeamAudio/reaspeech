--[[

  ReaSpeechWidgets.lua - collection of common widgets that ReaSpeech uses

]]--

ReaSpeechWidget = Polo {
}

function ReaSpeechWidget:init()
  assert(self.default ~= nil, "default value not provided")
  assert(self.renderer, "renderer not provided")
  self.ctx = self.ctx or ctx
  self.widget_id = self.widget_id or reaper.genGuid()
  self.on_set = nil
end

function ReaSpeechWidget:render(...)
  ImGui.PushID(self.ctx, self.widget_id)
  local args = ...
  app:trap(function()
    self.renderer(self, args)
  end)
  ImGui.PopID(self.ctx)
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
ReaSpeechCheckbox.new = function (options)
  options = options or {
    default = nil,
    label_long = nil,
    label_short = nil,
    width_threshold = nil,
  }

  options.changed_handler = options.changed_handler or function(_) end

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechCheckbox.renderer,
    options = options,
  })

  o._value = o.default
  options.changed_handler(o.default)

  return o
end

ReaSpeechCheckbox.simple = function(default_value, label, changed_handler)
  return ReaSpeechCheckbox.new {
    default = default_value,
    label_long = label,
    label_short = label,
    width_threshold = 0,
    changed_handler = changed_handler or function() end,
  }
end

ReaSpeechCheckbox.renderer = function (self, column)
  local options = self.options
  local label = options.label_long

  if column and column.width < options.width_threshold then
    label = options.label_short
  end

  local rv, value = ImGui.Checkbox(self.ctx, label, self:value())

  if rv then
    self:set(value)
    options.changed_handler(value)
  end
end

ReaSpeechTextInput = {}
ReaSpeechTextInput.new = function (options)
  options = options or {
    default = nil,
    label = nil,
  }

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechTextInput.renderer,
    options = options,
  })

  o._value = o.default

  return o
end

ReaSpeechTextInput.simple = function(default_value, label)
  return ReaSpeechTextInput.new {
    default = default_value,
    label = label
  }
end

ReaSpeechTextInput.renderer = function (self)
  local options = self.options

  ImGui.Text(self.ctx, options.label)
  ImGui.Dummy(self.ctx, 0, 0)

  local imgui_label = ("##%s"):format(options.label)

  local rv, value = ImGui.InputText(self.ctx, imgui_label, self:value())

  if rv then
    self:set(value)
  end
end

ReaSpeechCombo = {}

ReaSpeechCombo.new = function (options)
  options = options or {
    default = nil,
    label = nil,
    items = {},
    item_labels = {},
  }

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechCombo.renderer,
    options = options,
  })

  o._value = o.default

  return o
end

ReaSpeechCombo.renderer = function (self)
  local options = self.options

  ImGui.Text(self.ctx, options.label)
  ImGui.Dummy(self.ctx, 0, 0)

  local imgui_label = ("##%s"):format(options.label)

  if ImGui.BeginCombo(self.ctx, imgui_label, options.item_labels[self:value()]) then
    app:trap(function()
      for _, item in pairs(options.items) do
        local is_selected = (item == self:value())
        if ImGui.Selectable(self.ctx, options.item_labels[item], is_selected) then
          self:set(item)
        end
      end
    end)
    ImGui.EndCombo(self.ctx)
  end
end

ReaSpeechTabBar = {}

ReaSpeechTabBar.new = function (options)
  options = options or {
    default = nil,
    tabs = {},
  }

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechTabBar.renderer,
    options = options,
  })

  o._value = o.default

  return o
end

ReaSpeechTabBar.renderer = function (self)
  if ImGui.BeginTabBar(self.ctx, 'TabBar') then
    for _, tab in pairs(self.options.tabs) do
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

ReaSpeechButtonBar.new = function (options)
  options = options or {
    default = nil,
    label = nil,
    buttons = {},
    styles = {}
  }

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechButtonBar.renderer,
    options = options,
  })

  o._value = o.default

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
    column_padding = options.column_padding or 0,
    margin_bottom = options.margin_bottom or 0,
    margin_left = options.margin_left or 0,
    margin_right = options.margin_right or 0,
    width = options.width or 0,
    num_columns = #options.buttons,

    render_column = function (column)
      local bar_label = column.num == 1 and options.label or ""
      ImGui.Text(o.ctx, bar_label)
      ImGui.Dummy(o.ctx, 0, 0)

      local button_label, model_name = table.unpack(options.buttons[column.num])
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

ReaSpeechButton = {}
ReaSpeechButton.new = function(options)
  options = options or {
    label = nil,
    disabled = false,
    on_click = nil,
  }

  local o = ReaSpeechWidget.new({
    default = true,
    renderer = ReaSpeechButton.renderer,
    options = options,
  })

  return o
end

ReaSpeechButton.renderer = function(self)
  local disable_if = ReaUtil.disabler(self.ctx)

  disable_if(self.options.disabled, function()
    if ImGui.Button(self.ctx, self.options.label) then
      app:trap(self.options.on_click)
    end
  end)
end