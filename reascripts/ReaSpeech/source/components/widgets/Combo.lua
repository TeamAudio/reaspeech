--[[

  Combo.lua - Combo box widget for ReaSpeech

]]--

local Combo = {}
Widgets.Combo = Combo

Combo.new = function (options)
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
    renderer = Widgets.Combo.renderer,
    options = options,
  })

  return o
end

Combo.renderer = function (self)
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

