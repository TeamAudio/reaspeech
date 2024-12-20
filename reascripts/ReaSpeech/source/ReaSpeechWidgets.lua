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

ReaSpeechCheckbox = {}
ReaSpeechCheckbox.new = function (options)
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
    renderer = ReaSpeechCheckbox.renderer,
    options = options,
  })

  options.changed_handler(o:value())

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

ReaSpeechTextInput = {}
ReaSpeechTextInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or ''

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechTextInput.renderer,
    options = options,
  })

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

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local rv, value = ImGui.InputText(ctx, imgui_label, self:value())

  if rv then
    self:set(value)
  end
end

ReaSpeechNumberInput = {}
ReaSpeechNumberInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or 0

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechNumberInput.renderer,
    options = options,
  })

  return o
end

ReaSpeechNumberInput.simple = function(default_value, label)
  return ReaSpeechNumberInput.new {
    default = default_value,
    label = label
  }
end

ReaSpeechNumberInput.renderer = function (self)
  local options = self.options

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local rv, value = ImGui.InputInt(ctx, imgui_label, self:value())

  if rv and ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set(value)
  end
end

ReaSpeechCombo = {}

ReaSpeechCombo.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.items = options.items or {}
  options.item_labels = options.item_labels or {}

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechCombo.renderer,
    options = options,
  })

  return o
end

ReaSpeechCombo.renderer = function (self)
  local options = self.options

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)
  local item_label = options.item_labels[self:value()] or ""
  local combo_flags = ImGui.ComboFlags_HeightLarge()

  if ImGui.BeginCombo(ctx, imgui_label, item_label, combo_flags) then
    Trap(function()
      for _, item in pairs(options.items) do
        local is_selected = (item == self:value())
        if ImGui.Selectable(ctx, options.item_labels[item], is_selected) then
          self:set(item)
        end
      end
    end)
    ImGui.EndCombo(ctx)
  end
end

ReaSpeechTabBar = {}

ReaSpeechTabBar.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  options.tabs = options.tabs or {}

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechTabBar.renderer,
    options = options,
  })

  return o
end

ReaSpeechTabBar.renderer = function (self)
  if ImGui.BeginTabBar(ctx, 'TabBar') then
    for _, tab in pairs(self.options.tabs) do
      if ImGui.BeginTabItem(ctx, tab.label) then
        Trap(function()
          self:set(tab.key)
        end)
        ImGui.EndTabItem(ctx)
      end
    end
    ImGui.EndTabBar(ctx)
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

ReaSpeechFileSelector = {
  JSREASCRIPT_URL = 'https://forum.cockos.com/showthread.php?t=212174',
  has_js_ReaScriptAPI = function()
    return reaper.JS_Dialog_BrowseForSaveFile
  end
}

ReaSpeechFileSelector.new = function(options)
  options = options or {}
  options.default = options.default or ''
  local title = options.title or 'Save file'
  local folder = options.folder or ''
  local file = options.file or ''
  local ext = options.ext or ''
  local save = options.save or false
  local multi = options.multi or false

  local dialog_function
  if save then
    dialog_function = function()
      return reaper.JS_Dialog_BrowseForSaveFile(title, folder, file, ext)
    end
  else
    dialog_function = function()
      return reaper.JS_Dialog_BrowseForOpenFiles(title, folder, file, ext, multi)
    end
  end

  local o = ReaSpeechWidget.new({
    default = options.default,
    renderer = ReaSpeechFileSelector.renderer,
    options = options,
  })

  options.button = ReaSpeechButton.new({
    label = options.button_label or 'Choose File',
    disabled = not ReaSpeechFileSelector.has_js_ReaScriptAPI(),
    width = options.button_width,
    on_click = function()
      local rv, selected_file = dialog_function()
      if rv == 1 then
        o:set(selected_file)
      end
    end
  })

  return o
end

-- Display a text input for the output filename, with a Browse button if
-- the js_ReaScriptAPI extension is available.
ReaSpeechFileSelector.renderer = function(self)
  local options = self.options

  ImGui.Text(ctx, options.label)

  ReaSpeechFileSelector.render_jsapi_notice(self)

  options.button:render()
  ImGui.SameLine(ctx)

  local w, _
  if not options.input_width then
    w, _ = ImGui.GetContentRegionAvail(ctx)
  else
    w = options.input_width
  end

  ImGui.SetNextItemWidth(ctx, w)
  local hint = '...or type one here.'
  local file_changed, file = ImGui.InputTextWithHint(ctx, '##file', hint, self:value())
  if file_changed then
    self:set(file)
  end
end

ReaSpeechFileSelector.render_jsapi_notice = function(self)
  if ReaSpeechFileSelector.has_js_ReaScriptAPI() then
    return
  end

  local _, spacing_v = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing())
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, spacing_v)
  ImGui.Text(ctx, "To enable file selector, ")
  ImGui.SameLine(ctx)
  Widgets.link('install js_ReaScriptAPI', ReaUtil.url_opener(ReaSpeechFileSelector.JSREASCRIPT_URL))
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, ".")
  ImGui.PopStyleVar(ctx)
end

ReaSpeechListBox = {}

ReaSpeechListBox.new = function(options)
  options = options or {}

  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  options.items = options.items or {}
  options.item_labels = options.item_labels or {}

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = ReaSpeechListBox.renderer,
    options = options,
  })

  Logging.init(o, 'ReaSpeechListBox')

  return o
end

ReaSpeechListBox.renderer = function(self)
  local options = self.options

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local needs_update = false
  if ImGui.BeginListBox(ctx, imgui_label) then
    Trap(function()
      local current = self:value()
      local new_value = {}
      for i, item in ipairs(options.items) do
        new_value[item] = current[item] or false
        local is_selected = current[item]
        local label = options.item_labels[item]
        ImGui.PushID(ctx, 'item' .. i)
        Trap(function()
          local result, now_selected = ImGui.Selectable(ctx, label, is_selected)

          if result and is_selected ~= now_selected then
            needs_update = true
            new_value[item] = now_selected
          end
        end)
        ImGui.PopID(ctx)
      end

      if needs_update then
        self:set(new_value)
      end
    end)
    ImGui.EndListBox(ctx)
  end
end
