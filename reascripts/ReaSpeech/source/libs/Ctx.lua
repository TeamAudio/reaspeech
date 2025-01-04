--[[

  Ctx.lua - ImGui context builder that ensures a valid context

  Usage:

    Ctx.label = 'My Application'
    Ctx.flags = ImGui.ConfigFlags_DockingEnable()
    Ctx.on_create = function (ctx)
      -- Attach fonts, etc.
    end

    ImGui.Text(Ctx(), 'Hello, world!')

]]--

Ctx = {
  label = 'Application',
  flags = 0,
  ctx = nil,

  on_create = function (_ctx) end,

  __call = function (self)
    if not ImGui.ValidatePtr(self.ctx, 'ImGui_Context*') then
      self.ctx = ImGui.CreateContext(self.label, self.flags)
      self.on_create(self.ctx)
    end
    return self.ctx
  end
}

setmetatable(Ctx, Ctx)
