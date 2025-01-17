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

  local plugin_tabs = self.plugins:tabs()

  local tabs = {}
  for _, tab in ipairs(plugin_tabs) do
    table.insert(tabs, tab.tab)
  end
  self.tab_bar = Widgets.TabBar.new {
    default = tabs[1] and tabs[1].key or '',
    tabs = tabs,
  }
end

function ReaSpeechControlsUI:render()
  self:render_heading()
  for _, tab in ipairs(self.plugins:tabs()) do
    if tab:is_selected(self.tab_bar:value()) then
      tab:render()
    end
  end

  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 5)
end

function ReaSpeechControlsUI:render_heading()
  local init_x, init_y = ImGui.GetCursorPos(ctx)

  ImGui.SetCursorPosX(ctx, init_x - 20)
  Widgets.png('reaspeech-logo-small')

  ImGui.SetCursorPos(ctx, init_x + self.MARGIN_LEFT + 2, init_y)
  self.tab_bar:render()

  ImGui.SetCursorPos(ctx, ImGui.GetWindowWidth(ctx) - 55, init_y)
  Widgets.png('heading-logo-tech-audio')

  ImGui.SetCursorPos(ctx, init_x, init_y + 40)
end

function ReaSpeechControlsUI:render_input_label(text)
  ImGui.Text(ctx, text)
  ImGui.Dummy(ctx, 0, 0)
end
