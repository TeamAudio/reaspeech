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

  if ImGui.BeginTabBar(ctx, 'TabBar', tabbar_flags) then
    local tabs = self.options.tabs
    local current_value = self:value()

    if type(tabs) == 'function' then
      tabs = tabs()
    end

    for _, tab in pairs(tabs) do
      local label = tab.label

      if type(label) == 'function' then
        label = label()
      end

      local item_flags = ImGui.TabItemFlags_None()

      local closeable = tab.will_close and true or false

      if closeable then
        item_flags = item_flags | ImGui.TabItemFlags_NoAssumedClosure()
      end

      local tab_selected, tab_open = ImGui.BeginTabItem(ctx, label, closeable, item_flags)

      if (closeable and not tab_open) and tab.will_close() then
        tab.on_close()
      end

      if tab_selected then
        Trap(function()
          if current_value ~= tab.key then
            self:set(tab.key)
          end
        end)
        ImGui.EndTabItem(ctx)
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

return TabBar

end)()
