--[[

  Fonts.lua - Font configuration and loader

]]--

Fonts = {
  SIZE = 15,
}

function Fonts:load()
  self.main = ImGui.CreateFont('sans-serif', self.SIZE)
  ImGui.Attach(ctx, self.main)

  self.bold = ImGui.CreateFont('sans-serif', self.SIZE, ImGui.FontFlags_Bold())
  ImGui.Attach(ctx, self.bold)
end

function Fonts.wrap(ctx, font, f, trap_f)
  trap_f = trap_f or function(f_)
    return xpcall(f_, reaper.ShowConsoleMsg)
  end

  ImGui.PushFont(ctx, font)
  trap_f(function() f() end)
  ImGui.PopFont(ctx)
end
