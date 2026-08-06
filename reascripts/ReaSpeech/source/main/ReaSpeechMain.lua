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

  if not self:check_reaspeech_lib() then
    self:show_reaspeech_lib_required()
    return
  end

  app = ReaSpeechUI.new()
  app:present()

  reaper.defer(self:loop())
end

function ReaSpeechMain:check_reaspeech_lib()
  return reaper.ReaSpeech_StartEx
    and reaper.ReaSpeech_Poll
    and reaper.ReaSpeech_Cancel
end

function ReaSpeechMain:show_reaspeech_lib_required()
  local repository_url = 'https://github.com/TeamAudio/reascripts/raw/main/index.xml'

  app = AlertPopup.new {
    title = 'ReaSpeech Lib required',
    WIDTH = 600,
  }

  app.msg = function()
    ImGui.Text(Ctx(), 'This script requires ReaSpeech Lib, which can be installed from ReaPack.')
    ImGui.Spacing(Ctx())
    ImGui.Text(Ctx(), '1. If needed, import the TeamAudio repository:')
    ImGui.SetNextItemWidth(Ctx(), -1)
    ImGui.InputText(Ctx(), '##repository-url', repository_url, ImGui.InputTextFlags_ReadOnly())
    if ImGui.Button(Ctx(), 'Copy repository URL') then
      ImGui.SetClipboardText(Ctx(), repository_url)
    end
    ImGui.Spacing(Ctx())
    ImGui.Text(Ctx(), '2. Install ReaSpeech Lib from:')
    ImGui.Text(Ctx(), 'Extensions > ReaPack > Browse packages...')
    ImGui.Spacing(Ctx())
    ImGui.Text(Ctx(), '3. Restart REAPER after installation.')
  end

  app.react = function(self)
    self:render()
  end
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
