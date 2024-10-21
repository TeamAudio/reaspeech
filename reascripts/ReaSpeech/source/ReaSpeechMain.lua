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
  app:open()

  reaper.defer(self:loop())
end

function ReaSpeechMain:loop()
  return function()
    ImGui.PushFont(ctx, Fonts.main)

    if app:is_open() then
      if ReaSpeechUI.METRICS then
        ImGui.ShowMetricsWindow(ctx)
      end

      app:trap(function() app:react() end)

      reaper.defer(self:loop())
    end
    ImGui.PopFont(ctx)
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
