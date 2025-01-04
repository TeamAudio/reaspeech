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
  local disable_if = ReaUtil.disabler(ctx)
  local options = self.options

  disable_if(options.disabled, function()
    if ImGui.Button(ctx, options.label, options.width) then
      Trap(options.on_click)
    end
  end)
end

return Button

end)()
