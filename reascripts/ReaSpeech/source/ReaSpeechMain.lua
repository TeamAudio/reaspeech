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
  reaper.defer(self:loop())
end

function ReaSpeechMain:loop()
  local visible, open = false, false

  return function()
    ImGui.PushFont(ctx, Fonts.main)
    app:trap(function()
      Theme():push(ctx)
      app:trap(function()
        if ReaSpeechUI.METRICS then
          ImGui.ShowMetricsWindow(ctx)
        end

        ImGui.SetNextWindowSize(ctx, app.WIDTH, app.HEIGHT, ImGui.Cond_FirstUseEver())
        visible, open = ImGui.Begin(ctx, ReaSpeechUI.TITLE, true)

        if visible then
          app:trap(function()
            app:react()
          end)
          ImGui.End(ctx)
        end
      end)
      Theme():pop(ctx)
    end)
    ImGui.PopFont(ctx)

    if open then
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
