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

    if type(tabs) == 'function' then
      tabs = tabs()
    end

    for _, tab in pairs(tabs) do
      local label = tab.label

      if type(label) == 'function' then
        label = label()
      end

      if ImGui.BeginTabItem(ctx, label) then
        Trap(function()
          self:set(tab.key)
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
