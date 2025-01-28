--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  COLUMN_PADDING = 15,
  MARGIN_BOTTOM = 5,
  MARGIN_LEFT = 5,
  MARGIN_RIGHT = 0,
  NARROW_COLUMN_WIDTH = 150,
}

function ReaSpeechControlsUI:init()
  Logging().init(self, 'ReaSpeechControlsUI')

  assert(self.plugins, 'ReaSpeechControlsUI: plugins is required')

  self:init_tabs()
end

function ReaSpeechControlsUI:init_tabs()
  local function _tabs()
    local plugin_tabs = self.plugins:tabs()

    local tabs = {}
    for _, tab in ipairs(plugin_tabs) do
      table.insert(tabs, tab.tab)
    end

    table.insert(tabs, {
      key = 'new-tab',
      label = '+',
      position = 'trailing',
      on_click = function()
        ImGui.OpenPopup(ctx, 'new-tab-popup')
      end,
      render = function()
        if ImGui.BeginPopup(ctx, 'new-tab-popup') then
          for _, menu_item in ipairs(self.plugins:new_tab_menu()) do
            if ImGui.Selectable(ctx, menu_item.label) then
              menu_item.on_click()
            end
          end
          ImGui.EndPopup(ctx)
        end
      end
    })
    return tabs
  end

  local tabs = _tabs()

  self.tab_bar = Widgets.TabBar.new {
    default = tabs[1] and tabs[1].key or '',
    tabs = function() return _tabs() end,
  }
end

function ReaSpeechControlsUI:render()
  ImGui.BeginGroup(ctx)
  Trap(function()
    Widgets.png('reaspeech-logo-small')

    -- Nice big column under the logo to render into, ie
    -- if ImGui.Button(ctx, 'Metrics') then
    --   ReaSpeechUI.METRICS = not ReaSpeechUI.METRICS
    -- end
  end)
  ImGui.EndGroup(ctx)

  ImGui.SameLine(ctx)

  ImGui.BeginGroup(ctx)
  Trap(function()
    self:render_heading()

    if self._dropped_files then
      self:_render_drop_zone()
    else
      self:render_tab_content()
    end

  end)
  ImGui.EndGroup(ctx)

  -- Drop target applies to last appended item
  -- rendering it in all cases means you can
  -- drop a new transcript in even if one is already
  -- loaded.
  self:_render_drop_target()
end

function ReaSpeechControlsUI:_render_drop_zone()
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  local drop_zone_height = (avail_h - 10) / #self._drop_zones

  local theme = ImGuiTheme.new {
    colors = {
      { ImGui.Col_Border, 0xffffff00 },
    },
  }

  local theme_selected = ImGuiTheme.new {
    colors = {
      { ImGui.Col_Border, 0xffffffff },
    },
  }

  for i, drop_zone in ipairs(self._drop_zones) do
    local child_flags = ImGui.WindowFlags_None() | ImGui.ChildFlags_Border()

    local which_theme = drop_zone.hovered and theme_selected or theme

    which_theme:wrap(ctx, function()
      ImGui.BeginChild(ctx, 'drop-zone-' .. i, avail_w, drop_zone_height, child_flags)
      Trap(function()
        drop_zone:render()
      end)
      ImGui.EndChild(ctx)
      drop_zone.hovered = ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem())
    end, Trap)
  end
end

function ReaSpeechControlsUI:_render_drop_target()
  if ImGui.BeginDragDropTarget(ctx) then
    Trap(function()
      local dragdrop_flags = ImGui.DragDropFlags_AcceptNoPreviewTooltip()
        | (self._dragdrop_flags or ImGui.DragDropFlags_AcceptPeekOnly())

      local payload, count = ImGui.AcceptDragDropPayloadFiles(ctx, nil,
        dragdrop_flags | ImGui.DragDropFlags_AcceptNoDrawDefaultRect())

      if not payload then return end

      if dragdrop_flags == ImGui.DragDropFlags_AcceptNoPreviewTooltip() then
        self:_do_drag_drop()
      elseif not self._dropped_files then
        self:_init_drag_drop(count)
      end
    end)
    ImGui.EndDragDropTarget(ctx)
  elseif self._dropped_files then
    self:_reset_drag_drop()
  end
end

function ReaSpeechControlsUI:_init_drag_drop(file_count)
  local files = {}
  for i = 0, file_count do
    local file_result, file = ImGui.GetDragDropPayloadFile(ctx, i)
    if file_result then
      table.insert(files, file)
    end
  end

  if #files > 0 then
    self._drop_zones = self.plugins:drop_zones(files)
    self._dropped_files = files
    self._dragdrop_flags = ImGui.DragDropFlags_AcceptNoPreviewTooltip()
  end
end

function ReaSpeechControlsUI:_do_drag_drop()
  for _, drop_zone in ipairs(self._drop_zones) do
    if drop_zone.hovered then
      drop_zone:on_drop(self._dropped_files)
    end
  end

  self:_reset_drag_drop()
end

function ReaSpeechControlsUI:_reset_drag_drop()
  self._drop_zones = nil
  self._dropped_files = nil
  self._dragdrop_flags = nil
end

function ReaSpeechControlsUI:render_heading()
  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)

  local logo = IMAGES['heading-logo-tech-audio']

  local tab_bar_width = avail_w - logo.width - self.COLUMN_PADDING

  ImGui.BeginChild(ctx, 'tab-bar', tab_bar_width, logo.height)
  Trap(function ()
    self.tab_bar:render()
  end)
  ImGui.EndChild(ctx)

  ImGui.SameLine(ctx)

  Widgets.png(logo)
end

function ReaSpeechControlsUI:render_input_label(text)
  ImGui.Text(ctx, text)
  ImGui.Dummy(ctx, 0, 0)
end

function ReaSpeechControlsUI:render_tab_content()
  local tab_bar_value = self.tab_bar:value()

  for _, tab in ipairs(self.plugins:tabs()) do
    if tab.tab.key == tab_bar_value then
      ImGui.BeginChild(ctx, 'tab-content', 0, 0)
      Trap(function()
        tab:render()
      end)
      ImGui.EndChild(ctx)
    end

    if tab.render_bg then tab:render_bg() end
  end
end
