--[[

  ASRPlugin.lua - ASR plugin for ReaSpeech

]]--

ASRPlugin = Plugin {
  ENDPOINT = '/asr',
  PLUGIN_KEY = 'asr',
}

function ASRPlugin:init()
  assert(self.app, 'ASRPlugin: plugin host app is required')
  Logging().init(self, 'ASRPlugin')
  self._controls = ASRControls.new(self)
  self._actions = ASRActions.new(self)
end

function ASRPlugin:key()
  return self.PLUGIN_KEY
end

function ASRPlugin:importer()
  return self._controls.importer
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

  -- consolidate jobs by path, retaining a collection of
  -- { item: MediaItem, take: MediaItem_Take } objects
  -- so that we can process a single file but reflect its
  -- possibly multi-presence in the timeline

  local consolidated_jobs = {}
  local seen_path_index = {}
  for _, job in pairs(jobs) do
    local path = job.path

    if not seen_path_index[path] then
      table.insert(consolidated_jobs, {path = path, project_entries = {}})
      seen_path_index[path] = #consolidated_jobs
    end

    local index = seen_path_index[path]
    local project_entries = consolidated_jobs[index].project_entries

    table.insert(project_entries, { item = job.item, take = job.take })
  end

  local request = {
    data = data,
    file_uploads = {
      audio_file = function(job) return job.path end
    },
    jobs = consolidated_jobs,
    endpoint = self.ENDPOINT,
    callback = self:handle_response(#consolidated_jobs)
  }

  self.app:submit_request(request)
end

function ASRPlugin:handle_response(job_count)
  local transcript = Transcript.new {
    name = self.new_transcript_name(),
  }

  return function(response)
    if not response[1] or not response[1].segments then
      return
    end

    local segments = response[1].segments
    local job = response._job

    for _, project_entry in pairs(job.project_entries) do
      local item = project_entry.item
      local take = project_entry.take

      for _, segment in pairs(segments) do
        local from_whisper = TranscriptSegment.from_whisper(segment, item, take)

        for _, s in pairs(from_whisper) do
          -- do we get a lot of textless segments? thinking emoji
          if s:get('text') then
            transcript:add_segment(s)
          end
        end
      end
    end

    transcript:update()

    job_count = job_count - 1

    if job_count == 0 then
      local plugin = TranscriptUI.new { transcript = transcript }
      self.app.plugins:add_plugin(plugin)
    end
  end
end

ASRPlugin.new_transcript_name = function()
  local time = os.time()
  local date_start = os.date('%b %d, %Y @ %I:%M', time)
  ---@diagnostic disable-next-line: param-type-mismatch
  local am_pm = string.lower(os.date('%p', time))

  return date_start .. am_pm
end
