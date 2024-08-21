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
