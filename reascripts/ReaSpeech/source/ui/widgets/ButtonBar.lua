--[[

  ButtonBar.lua - Button bar widget

]]--

Widgets.ButtonBar = (function()

local ButtonBar = {}

ButtonBar.new = function (options)
  options = options or {}

  -- nothing is selected by default
  options.default = options.default or nil

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.buttons = options.buttons or {}
  options.styles = options.styles or {}

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = Widgets.ButtonBar.renderer,
    options = options,
  })

  local with_button_color = function (selected, f)
    local color = Theme.COLORS.dark_gray_translucent
    if selected then color = Theme.COLORS.medium_gray_opaque end
    ImGui.PushStyleColor(Ctx(), ImGui.Col_Button(), color)
    ImGui.PushStyleColor(Ctx(), ImGui.Col_ButtonHovered(), color)
    Trap(f)
    ImGui.PopStyleColor(Ctx(), 2)
  end

  o.layout = ColumnLayout.new {
    column_padding = options.column_padding or 0,
    margin_bottom = options.margin_bottom or 0,
    margin_left = options.margin_left or 0,
    margin_right = options.margin_right or 0,
    width = options.width or 0,
    num_columns = #options.buttons,

    render_column = function (column)
      local bar_label = column.num == 1 and options.label or ""
      o:render_label(bar_label)

      local button_label, model_name = table.unpack(options.buttons[column.num])
      with_button_color(o:value() == model_name, function ()
        if ImGui.Button(Ctx(), button_label, column.width) then
          o:set(model_name)
        end
      end)
    end
  }
  return o
end

ButtonBar.renderer = function (self)
  self.layout:render()
end

return ButtonBar

end)()
