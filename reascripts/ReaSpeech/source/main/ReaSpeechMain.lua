--[[

  ReaSpeechMain.lua - ReaSpeech main class

]]--

ctx = nil
app = nil

ReaSpeechMain = {}

function ReaSpeechMain:main()
  if not self:check_imgui() then return end
  reaper.atexit(function () self:on_exit() end)

  self:init_ctx()
  ctx = Ctx()

  Theme:init()
  app = ReaSpeechUI.new()
  app:present()

  reaper.defer(self:loop())
end

function ReaSpeechMain:loop()
  return function()
    if app:presenting() or app:is_open() then
      ctx = Ctx()
      Fonts:check(ctx)
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

function ReaSpeechMain:init_ctx()
  Ctx.label = ReaSpeechUI.TITLE
  Ctx.flags = ReaSpeechUI.config_flags()
  Ctx.on_create = function (ctx)
    Fonts:init(ctx)
  end
end

function ReaSpeechMain:on_exit()
  Tempfile:remove_all()
end
