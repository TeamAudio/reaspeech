--[[

  ListBox.lua - ListBox ReaSpeechWidget

]]--

Widgets.ListBox = (function()

local ListBox = {}

ListBox.new = function(options)
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
    renderer = ListBox.renderer,
    options = options,
  })

  Logging().init(o, 'Widgets.ListBox')

  return o
end

ListBox.renderer = function(self)
  local options = self.options

  self:render_label()

  local imgui_label = ("##%s"):format(options.label)

  local needs_update = false
  if ImGui.BeginListBox(Ctx(), imgui_label) then
    Trap(function()
      local current = self:value()
      local new_value = {}
      for i, item in ipairs(options.items) do
        new_value[item] = current[item] or false
        local is_selected = current[item]
        local label = options.item_labels[item]
        ImGui.PushID(Ctx(), 'item' .. i)
        Trap(function()
          local result, now_selected = ImGui.Selectable(Ctx(), label, is_selected)

          if result and is_selected ~= now_selected then
            needs_update = true
            new_value[item] = now_selected
          end
        end)
        ImGui.PopID(Ctx())
      end

      if needs_update then
        self:set(new_value)
      end
    end)
    ImGui.EndListBox(Ctx())
  end
end

return ListBox

end)()
