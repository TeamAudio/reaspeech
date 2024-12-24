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
  self.widget_id = self.widget_id or reaper.genGuid()
  self.on_set = self.options and self.options.on_set or function() end
end

function ReaSpeechWidget:render(...)
  ImGui.PushID(ctx, self.widget_id)
  local args = ...
  Trap(function()
    self.renderer(self, args)
  end)
  ImGui.PopID(ctx)
end

function ReaSpeechWidget:render_help_icon()
  local options = self.options
  local size = Fonts.size:get()
  Widgets.icon(Icons.info, '##help-text', size, size, options.help_text, 0xffffffa0, 0xffffffff)
end

function ReaSpeechWidget:render_label(label)
  local options = self.options
  label = label or options.label

  ImGui.Text(ctx, label)

  if label ~= '' and options.help_text then
    ImGui.SameLine(ctx)
    self:render_help_icon()
  end

  ImGui.Dummy(ctx, 0, 0)
end

function ReaSpeechWidget:value()
  return self.state:get()
end

function ReaSpeechWidget:set(value)
  self.state:set(value)
  if self.on_set then self:on_set() end
end

-- Widget Implementations

ReaSpeechButtonBar = {}

ReaSpeechButtonBar.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.buttons = options.buttons or {}
  options.styles = options.styles or {}

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechButtonBar.renderer,
    options = options,
  })

  local with_button_color = function (selected, f)
    local color = Theme.COLORS.dark_gray_translucent
    if selected then color = Theme.COLORS.medium_gray_opaque end
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), color)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), color)
    Trap(f)
    ImGui.PopStyleColor(ctx, 2)
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
      o:render_label(bar_label)

      local button_label, model_name = table.unpack(options.buttons[column.num])
      with_button_color(o:value() == model_name, function ()
        if ImGui.Button(ctx, button_label, column.width) then
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
  options = options or {}

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.disabled = options.disabled or false

  if not options.disabled then
    assert(options.on_click, "on_click handler not provided")
  end

  local o = ReaSpeechWidget.new({
    default = true,
    renderer = ReaSpeechButton.renderer,
    options = options,
  })

  return o
end

ReaSpeechButton.renderer = function(self)
  local disable_if = ReaUtil.disabler(ctx)
  local options = self.options

  disable_if(options.disabled, function()
    if ImGui.Button(ctx, options.label, options.width) then
      Trap(options.on_click)
    end
  end)
end


