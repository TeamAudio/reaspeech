--[[

  TabBar.lua - TabBar widget

]]--

Widgets.TabBar = (function()

local TabBar = {}

TabBar.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  options.tabs = options.tabs or {}

  local o = ReaSpeechWidget.new({
    default = options.default,
    widget_id = options.widget_id,
    renderer = Widgets.TabBar.renderer,
    options = options,
  })

  return o
end

TabBar.renderer = function (self)
  local tabbar_flags = ImGui.TabBarFlags_None()
                     | ImGui.TabBarFlags_AutoSelectNewTabs()
                     | ImGui.TabBarFlags_FittingPolicyScroll()
                     | ImGui.TabBarFlags_NoTabListScrollingButtons()

  if ImGui.BeginTabBar(ctx, 'TabBar', tabbar_flags) then
    local tabs = self.options.tabs
    local current_value = self:value()

    if type(tabs) == 'function' then
      tabs = tabs()
    end

    for _, tab in pairs(tabs) do
      if tab.on_click then
        TabBar.render_tab_button(self, tab)
      else
        TabBar.render_tab_item(self, tab, current_value)
      end
    end
    ImGui.EndTabBar(ctx)
  end
end

TabBar.tab = function(key, label)
  return {
    key = key,
    label = label
  }
end

TabBar.render_tab_button = function(self, tab)
  if ImGui.TabItemButton(ctx, tab.label, TabBar.tab_flags(tab)) then
    tab.on_click()
  end
  tab.render()
end

TabBar.tab_flags = function(tab)
  local flags = ImGui.TabItemFlags_None()

  if tab.position == 'leading' then
    flags = flags | ImGui.TabItemFlags_Leading()
  elseif tab.position == 'trailing' then
    flags = flags | ImGui.TabItemFlags_Trailing()
  end

  return flags
end

TabBar.render_tab_item = function(self, tab, current_value)
  local label = tab.label

  if type(label) == 'function' then
    label = label()
  end

  local flags =  TabBar.tab_flags(tab)

  local closeable = tab.will_close and true or false

  if closeable then
    flags = flags | ImGui.TabItemFlags_NoAssumedClosure()
  end

  local tab_selected, tab_open = ImGui.BeginTabItem(ctx, label, closeable, flags)

  Trap(function()
    if (closeable and not tab_open) and tab.will_close() then
      tab.on_close()
    end
  end)

  if tab_selected then
    Trap(function()
      if current_value ~= tab.key then
        self:set(tab.key)
      end
    end)
    ImGui.EndTabItem(ctx)
  end
end

return TabBar

end)()
