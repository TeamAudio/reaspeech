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
    self:render_tab_content()
  end)
  ImGui.EndGroup(ctx)

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
      tab:render()
    end

    if tab.render_bg then tab:render_bg() end
  end
end
