--[[

  Button.lua - Button widget

]]--

Widgets.Button = (function()

local Button = {}

Button.new = function(options)
  options = options or {}

  -- nil label won't render anything that takes space
  options.label = options.label or ""

  options.disabled = options.disabled or false

  if not options.disabled then
    assert(options.on_click, "on_click handler not provided")
  end

  local o = ReaSpeechWidget.new({
    default = true,
    renderer = Widgets.Button.renderer,
    options = options,
  })

  return o
end

Button.renderer = function(self)
  local options = self.options

  local disabled = options.disabled
  if type(disabled) == 'function' then
    disabled = disabled()
  end

  Widgets.disable_if(disabled, function()
    if ImGui.Button(ctx, options.label, options.width) then
      Trap(options.on_click)
    end
  end)
end

return Button

end)()
