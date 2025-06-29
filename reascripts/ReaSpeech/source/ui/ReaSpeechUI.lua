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
  ToolWindow.init(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    window_flags = ImGui.WindowFlags_None(),
    font = Fonts.main,
    theme = Theme.main,
    position = ToolWindow.POSITION_AUTOMATIC,
  })

  Logging().init(self, 'ReaSpeechUI')

  Trap.on_error = function (e)
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

  self.plugins = ReaSpeechPlugins.new(self, {
    ASRPlugin,
    -- DetectLanguagePlugin,
    -- SampleMultipleUploadPlugin,
    TranscriptUI.plugin(),
  })

  self.controls_ui = ReaSpeechControlsUI.new({
    plugins = self.plugins,
  })

  self.alert_popup = AlertPopup.new {}

  self.react_handlers = self:get_react_handlers()
end

ReaSpeechUI.config_flags = function ()
  return ImGui.ConfigFlags_DockingEnable()
end

function ReaSpeechUI:react()
  for _, handler in pairs(self.react_handlers) do
    Trap(handler)
  end
end

function ReaSpeechUI:get_react_handlers()
  return {
    function() self:react_to_worker_response() end,
    function() Logging():react() end,
    function() self.worker:react() end,
    function() self:render() end
  }
end

function ReaSpeechUI:react_to_worker_response()
  local response = table.remove(self.responses, 1)

  if not response then
    return
  end

  -- self:debug('Response: ' .. dump(response))

  if response.error then
    self.alert_popup:show('Transcription Failed', response.error)
    self.worker:cancel()
    return
  end

  if response.callback then
    response.callback(response)
  end
end

function ReaSpeechUI:render_content()
  if ReaSpeechUI.METRICS then
    ImGui.ShowMetricsWindow(Ctx())
  end

  Trap(function ()
    if self.welcome_ui then
      self.welcome_ui:render()
    end
    self.controls_ui:render()
    self.alert_popup:render()
  end)
end

function ReaSpeechUI:load_transcript(transcript)
  local plugin = TranscriptUI.new {
    transcript = transcript,
    _transcript_saved = true
  }
  self.plugins:add_plugin(plugin)
end

function ReaSpeechUI:submit_request(request)
  assert(request.endpoint, "Endpoint required for API call")
  request.callback = request.callback or function() end
  table.insert(self.requests, request)
end
