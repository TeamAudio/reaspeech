--[[

  ASRPlugin.lua - ASR plugin for ReaSpeech

]]--

ASRPlugin = Polo {
  new = function(app)
    return {
      app = app
    }
  end,
}

function ASRPlugin:init()
  assert(self.app, 'ASRPlugin: plugin host app is required')
  Logging.init(self, 'ASRPlugin')
  self._controls = ASRControls.new(self)
  self._actions = ASRActions.new(self)
end

function ASRPlugin:tabs()
  return self._controls:tabs()
end

function ASRPlugin:actions()
  return self._actions:actions()
end

function ASRPlugin:asr(jobs)
  local controls_data = self._controls:get_request_data()

  local data = {
    task = controls_data.translate and 'translate' or 'transcribe',
    output = 'json',
    use_async = 'true',
    vad_filter = controls_data.vad_filter and 'true' or 'false',
    word_timestamps = 'true',
    model_name = controls_data.model_name,
  }

  if controls_data.language and controls_data.language ~= '' then
    data.language = controls_data.language
  end

  if controls_data.hotwords and controls_data.hotwords ~= '' then
    data.hotwords = controls_data.hotwords
  end

  if controls_data.initial_prompt and controls_data.initial_prompt ~= '' then
    data.initial_prompt = controls_data.initial_prompt
  end

  local request = {
    data = data,
    jobs = jobs,
    endpoint = ReaSpeechAPI.endpoints.asr,
    callback = self:handle_response()
  }

  self.app.transcript:clear()

  self.app:submit_request(request)
end

function ASRPlugin:handle_response()
  return function(response)
    if not response.segments then
      return
    end

    for _, segment in pairs(response.segments) do
      for _, s in pairs(
        TranscriptSegment.from_whisper(segment, response._job.item, response._job.take)
      ) do
        if s:get('text') then
          self.app.transcript:add_segment(s)
        end
      end
    end

    self.app.transcript:update()
  end
end
