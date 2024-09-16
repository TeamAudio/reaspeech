--[[

  ReaSpeechUI.lua - ReaSpeech user interface

]]--

ReaSpeechUI = Polo {
  VERSION = "unknown (development)",
  -- Set to show ImGui Metrics/Debugger window
  METRICS = false,

  TITLE = 'ReaSpeech',
  WIDTH = 1000,
  HEIGHT = 600,

  ITEM_WIDTH = 125,
}

function ReaSpeechUI:init()
  Logging.init(self, 'ReaSpeechUI')

  self.onerror = function (e)
    self:log(e)
  end

  self.requests = {}
  self.responses = {}

  ReaSpeechAPI:init(Script.host, Script.protocol)

  self.worker = ReaSpeechWorker.new({
    requests = self.requests,
    responses = self.responses,
  })

  if Script.env == 'demo' then
    self.welcome_ui = ReaSpeechWelcomeUI.new { is_demo = true }
    self.welcome_ui:present()
  end

  self.plugins = ReaSpeechPlugins.new(self, { ASRPlugin, SettingsPlugin })

  self.controls_ui = ReaSpeechControlsUI.new({
    plugins = self.plugins,
  })

  self.actions_ui = ReaSpeechActionsUI.new({
    plugins = self.plugins,
    worker = self.worker
  })

  self.transcript = Transcript.new()
  self.transcript_ui = TranscriptUI.new { transcript = self.transcript }

  self.failure = AlertPopup.new { title = 'Transcription Failed' }

  self.react_handlers = self:get_react_handlers()
end

ReaSpeechUI.config_flags = function ()
  return ImGui.ConfigFlags_DockingEnable()
end

function ReaSpeechUI:trap(f)
  return xpcall(f, self.onerror)
end

function ReaSpeechUI:has_js_ReaScriptAPI()
  if reaper.JS_Dialog_BrowseForSaveFile then
    return true
  end
  return false
end

function ReaSpeechUI:show_file_dialog(options)
  local title = options.title or 'Save file'
  local folder = options.folder or ''
  local file = options.file or ''
  local ext = options.ext or ''
  local save = options.save or false
  local multi = options.multi or false
  if self:has_js_ReaScriptAPI() then
    if save then
      return reaper.JS_Dialog_BrowseForSaveFile(title, folder, file, ext)
    else
      return reaper.JS_Dialog_BrowseForOpenFiles(title, folder, file, ext, multi)
    end
  else
    return nil
  end
end

function ReaSpeechUI:react()
  for _, handler in pairs(self.react_handlers) do
    self:trap(handler)
  end
end

function ReaSpeechUI:get_react_handlers()
  return {
    function() self:react_to_worker_response() end,
    function() Logging:react() end,
    function() self.worker:react() end,
    function() self:render() end
  }
end

function ReaSpeechUI:react_to_worker_response()
  local response = table.remove(self.responses, 1)

  if not response then
    return
  end

  self:debug('Response: ' .. dump(response))

  if response.error then
    self.failure:show(response.error)
    self.worker:cancel()
    return
  end

  if response.callback then
    response.callback(response)
  end
end

function ReaSpeechUI:render()
  ImGui.PushItemWidth(ctx, self.ITEM_WIDTH)

  self:trap(function ()
    if self.welcome_ui then
      self.welcome_ui:render()
    end
    self.controls_ui:render()
    self.actions_ui:render()
    self.transcript_ui:render()
    self.failure:render()
  end)

  ImGui.PopItemWidth(ctx)
end

function ReaSpeechUI:submit_request(request)
  assert(request.endpoint, "Endpoint required for API call")
  request.callback = request.callback or function() end
  table.insert(self.requests, request)
end

function ReaSpeechUI.get_source_path(take)
  local source = reaper.GetMediaItemTake_Source(take)
  if source then
    local source_path = reaper.GetMediaSourceFileName(source)
    return source_path
  end
  return nil
end
