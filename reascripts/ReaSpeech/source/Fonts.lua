--[[

  Fonts.lua - Font configuration and loader

]]--

Fonts = {
  SIZE = 15,
  ICON = {
    pencil = 'a',
    cog = 'b',
    play = 'c',
    stop = 'd',
  },
  LOCAL_FILE = nil,
}

function Fonts:load()
  self.main = ImGui.CreateFont('sans-serif', self.SIZE)
  ImGui.Attach(ctx, self.main)

  if self.LOCAL_FILE then
    self.icons = ImGui.CreateFont(self.LOCAL_FILE, self.SIZE)
    ImGui.Attach(ctx, self.icons)
    return
  end

  if not Script or not Script.host or Script.host == '' then
    return
  end

  local protocol = Script.protocol or 'http:'
  local icons_url = protocol .. '//' .. Script.host .. '/static/reascripts/ReaSpeech/icons.ttf'
  local icons_file = Tempfile:name()

  local curl = "curl"
  if not reaper.GetOS():find("Win") then
    curl = "/usr/bin/curl"
  end
  local command = (
    curl
    .. ' "' .. icons_url .. '"'
    .. ' -o "' .. icons_file .. '"'
  )

  if reaper.ExecProcess(command, 5000) then
    self.icons = ImGui.CreateFont(icons_file, self.SIZE)
    ImGui.Attach(ctx, self.icons)
  else
    self.icons = self.main
  end

end
