--[[

  ReaSpeechWorker.lua - ReaSpeech Lib transcription worker

]]--

ReaSpeechWorker = Polo {}

function ReaSpeechWorker:init()
  assert(self.requests, 'missing requests')
  assert(self.responses, 'missing responses')
  Logging().init(self, 'ReaSpeechWorker')
  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:react()
  local request = table.remove(self.requests, 1)
  if request then self:handle_request(request) end

  if self.active_job then
    self:poll_active_job()
  else
    self:start_next_job()
  end
end

function ReaSpeechWorker:handle_request(request)
  self:log('Processing speech...')
  local jobs = self:expand_jobs_from_request(request)
  self.job_count = self.job_count + #jobs
  for _, job in ipairs(jobs) do
    table.insert(self.pending_jobs, job)
  end
end

function ReaSpeechWorker:expand_jobs_from_request(request)
  local jobs = {}
  local seen_path = {}
  for _, job in ipairs(request.jobs or {}) do
    if job.path and not seen_path[job.path] then
      seen_path[job.path] = true
      table.insert(jobs, {
        job = job,
        data = request.data or {},
        callback = request.callback,
        segments = {},
        progress = 0,
        status = 'Waiting',
      })
    end
  end
  return jobs
end

function ReaSpeechWorker:start_next_job()
  self.active_job = table.remove(self.pending_jobs, 1)
  if not self.active_job then
    if self.job_count > 0 then self:log('Processing finished') end
    self.job_count = 0
    return
  end

  local active = self.active_job
  local data = active.data
  active.status = 'Starting'
  active.job_id = reaper.ReaSpeech_Start(
    active.job.path,
    data.model_name or 'small',
    data.language or '',
    data.task == 'translate',
    data.vad_filter == true or data.vad_filter == 'true',
    true
  )

  if type(active.job_id) ~= 'string' or active.job_id:sub(1, 6) == 'ERROR:' then
    self:finish_with_error(active.job_id or 'Unable to start transcription')
  end
end

function ReaSpeechWorker:poll_active_job()
  local active = self.active_job
  while active and self.active_job == active do
    local event_json = reaper.ReaSpeech_Poll(active.job_id)
    if not event_json or event_json == '' then return end

    local ok, event = pcall(json.decode, event_json)
    if not ok then
      self:finish_with_error('Could not decode ReaSpeech Lib response: ' .. tostring(event))
      return
    end
    self:handle_event(event)
  end
end

function ReaSpeechWorker:handle_event(event)
  local active = self.active_job
  if event.type == 'started' then
    active.status = 'Transcribing'
  elseif event.type == 'progress' then
    local total = tonumber(event.total) or 100
    active.progress = total > 0 and math.min((tonumber(event.completed) or 0) / total, 1) or 0
    active.status = event.message or 'Transcribing'
  elseif event.type == 'segment' and event.segment then
    table.insert(active.segments, self:convert_segment(event.segment))
  elseif event.type == 'completed' then
    local response = {
      { segments = active.segments },
      _job = active.job,
      callback = active.callback,
    }
    table.insert(self.responses, response)
    self.active_job = nil
    self:start_next_job()
  elseif event.type == 'cancelled' then
    self.active_job = nil
  elseif event.type == 'error' then
    self:finish_with_error(event.error or 'Unknown transcription error')
  end
end

function ReaSpeechWorker:convert_segment(segment)
  local result = {
    start = (tonumber(segment.startMs) or 0) / 1000,
    ['end'] = (tonumber(segment.endMs) or 0) / 1000,
    text = segment.text or '',
  }
  if segment.confidence ~= nil then result.confidence = segment.confidence end
  if segment.words then result.words = segment.words end
  return result
end

function ReaSpeechWorker:finish_with_error(message)
  table.insert(self.responses, { error = tostring(message) })
  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:progress()
  if self.job_count == 0 then return nil end
  local remaining = #self.pending_jobs + (self.active_job and 1 or 0)
  local active_progress = self.active_job and self.active_job.progress or 0
  return (self.job_count - remaining + active_progress) / self.job_count
end

function ReaSpeechWorker:status()
  return self.active_job and self.active_job.status or nil
end

function ReaSpeechWorker:cancel()
  if self.active_job and self.active_job.job_id then
    reaper.ReaSpeech_Cancel(self.active_job.job_id)
  end
  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end
