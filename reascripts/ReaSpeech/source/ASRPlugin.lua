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
  local request = self._controls:get_request_data()
  request.endpoint = ReaSpeechAPI.endpoints.asr
  request.jobs = jobs
  request.callback = self:handle_response()

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
