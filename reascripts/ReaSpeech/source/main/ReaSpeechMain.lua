--[[

  ReaSpeechMain.lua - ReaSpeech main class

]]--

app = nil

ReaSpeechMain = {}

function ReaSpeechMain:main()
  if not self:check_imgui() then return end
  reaper.atexit(function () self:on_exit() end)

  self:init_logging()
  self:init_ctx()

  Theme:init()
  app = ReaSpeechUI.new()
  app:present()

  reaper.defer(self:loop())
end

function ReaSpeechMain:loop()
  return function()
    if app:presenting() or app:is_open() then
      Fonts:check(Ctx())
      Trap(function() app:react() end)
      reaper.defer(self:loop())
    end
  end
end

function ReaSpeechMain:check_imgui()
  if ImGui.CreateContext then
    local _, _, reaimgui_version_string = ImGui.GetVersion()

    local major, minor = reaimgui_version_string:match("(%d+)%.(%d+)")
    major = tonumber(major)
    minor = tonumber(minor)

    if major == 0 and minor < 10 then
      reaper.MB(
        "ReaSpeech requires ReaImGui version 0.10 or higher.\n\n"
        .. "Please update ReaImGui from:\n\n"
        .. "Extensions > ReaPack > Browse packages...",
        "ReaImGui version error",
        0
      )
      return false
    end


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
  Ctx()
end

function ReaSpeechMain:init_logging()
  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.Logging',
    persist = true,
  }

  Logging().show_logs = storage:boolean('show_logs', false)
  Logging().show_debug_logs = storage:boolean('show_debug_logs', false)
end

function ReaSpeechMain:on_exit()
  Tempfile:remove_all()
end
