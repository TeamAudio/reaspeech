--[[

  Combo.lua - Combo box widget for ReaSpeech

]]--

Widgets.Combo = (function()

local Combo = {}

Combo.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.items = options.items or {}
  options.item_labels = options.item_labels or {}

  options.on_change = options.on_change or function() end

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = Widgets.Combo.renderer,
    options = options,
  })

  return o
end

Combo.renderer = function (self)
  local options = self.options

  if options.label and options.label ~= '' then
    self:render_label()
  end

  local items = type(options.items) == 'function' and options.items() or options.items
  local item_labels = type(options.item_labels) == 'function' and options.item_labels() or options.item_labels

  local imgui_label = ("##%s"):format(options.label)
  local item_label = item_labels[self:value()] or ""
  local combo_flags = ImGui.ComboFlags_HeightLarge()

  local width = options.width and (type(options.width) == 'function' and options.width() or options.width) or nil

  if width then
    ImGui.SetNextItemWidth(Ctx(), width)
  end

  if ImGui.BeginCombo(Ctx(), imgui_label, item_label, combo_flags) then
    Trap(function()
      for _, item in pairs(items) do
        local is_selected = (item == self:value())
        if ImGui.Selectable(Ctx(), item_labels[item], is_selected) then
          self:set(item)
          options.on_change(item)
        end
      end
    end)
    ImGui.EndCombo(Ctx())
  end
end

return Combo

end)()
