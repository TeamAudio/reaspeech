--[[

  TextInput.lua - TextInput Widget

]]--

Widgets.TextInput = (function()

local TextInput = {}

TextInput.new = function (options)
  options = options or {
    label = nil,
  }
  options.default = options.default or ''

  options.disabled = options.disabled or function() return false end

  options.on_cancel = options.on_cancel or function() end

  options.on_change = options.on_change or function() end

  options.on_enter = options.on_enter or function() end

  local o = ReaSpeechWidget.new({
    state = options.state,
    default = options.default,
    widget_id = options.widget_id,
    renderer = TextInput.renderer,
    options = options,
  })

  -- Abandon any in-progress edit; the next render reads from state.
  -- Used when the value is changed programmatically mid-edit
  -- (e.g. autocomplete completing the text being typed).
  o.clear_edit_buffer = function(widget)
    widget._edit_buffer = nil
  end

  return o
end

TextInput.simple = function(default_value, label)
  return TextInput.new {
    default = default_value,
    label = label
  }
end

TextInput.renderer = function (self)
  local options = self.options

  if options.label then
    self:render_label()
  end

  local imgui_label = ("##%s"):format(options.label)

  local width = options.width and (type(options.width) == 'function' and options.width() or options.width) or nil

  if width then
    ImGui.SetNextItemWidth(Ctx(), width)
  end

  -- While the input is being edited, keystrokes accumulate in a local
  -- buffer; state (which may be disk-backed) is only written when the
  -- edit ends. on_change still fires per keystroke for live feedback.
  local buffer = self._edit_buffer or self:value()

  local rv, value
  Widgets.disable_if(options.disabled(), function()
    if options.hint and options.hint ~= '' then
      rv, value = ImGui.InputTextWithHint(Ctx(), imgui_label, options.hint, buffer)
    else
      rv, value = ImGui.InputText(Ctx(), imgui_label, buffer)
    end
  end)

  if rv then
    self._edit_buffer = value
    self.options.on_change(value)
  end

  if ImGui.IsItemDeactivated(Ctx()) then
    local final_value = self._edit_buffer
    self._edit_buffer = nil

    if ImGui.IsKeyPressed(Ctx(), ImGui.Key_Escape()) then
      self.options.on_cancel()
    elseif final_value ~= nil then
      self:set(final_value)
      self.options.on_enter(final_value)
    else
      self.options.on_enter(self:value())
    end
  end
end

return TextInput

end)()
