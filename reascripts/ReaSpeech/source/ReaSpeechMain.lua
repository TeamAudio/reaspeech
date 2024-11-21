--[[

  ReaSpeechMain.lua - ReaSpeech main class

]]--

ctx = nil
app = nil

ReaSpeechMain = {}

function ReaSpeechMain:main()
  if not self:check_imgui() then return end
  reaper.atexit(function () self:onexit() end)

  ctx = ImGui.CreateContext(ReaSpeechUI.TITLE, ReaSpeechUI.config_flags())
  Fonts:load()
  app = ReaSpeechUI.new()
  app:present()
  reaper.defer(self:loop())
end

function ReaSpeechMain:loop()
  return function()
    if app:presenting() or app:is_open() then
      Trap(function() app:react() end)
      reaper.defer(self:loop())
    end
  end
end

function ReaSpeechMain:check_imgui()
  if ImGui.CreateContext then
    return true
  else
    reaper.MB(
      "This script requires the ReaImGui API, which can be installed from:\n\n"
      .. "Extensions > ReaPack > Browse packages...",
      "ReaImGui required",
      0
    )
    return false
  end
end

function ReaSpeechMain:onexit()
  Tempfile:remove_all()
end
