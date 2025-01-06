--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  COLUMN_PADDING = 15,
  MARGIN_BOTTOM = 5,
  MARGIN_LEFT = 115,
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
  self:render_heading()

  local tab_bar_value = self.tab_bar:value()

  for _, tab in ipairs(self.plugins:tabs()) do
    if tab.tab.key == tab_bar_value then
      tab:render()
    end

    if tab.render_bg then tab:render_bg() end
  end
end

function ReaSpeechControlsUI:render_heading()
  local init_x, init_y = ImGui.GetCursorPos(ctx)

  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)

  ImGui.SetCursorPosX(ctx, init_x - 20)
  Widgets.png('reaspeech-logo-small')

  ImGui.SetCursorPos(ctx, init_x + self.MARGIN_LEFT + 2, init_y)
  self.tab_bar:render()

  ImGui.SetCursorPos(ctx, avail_w - 55, init_y)
  Widgets.png('heading-logo-tech-audio')

  ImGui.SetCursorPos(ctx, init_x, init_y + 40)
end

function ReaSpeechControlsUI:render_input_label(text)
  ImGui.Text(ctx, text)
  ImGui.Dummy(ctx, 0, 0)
end
