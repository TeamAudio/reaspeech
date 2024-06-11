--[[

  ReaSpeechWorker.lua - Speech transcription worker

]]--

ReaSpeechWorker = Polo {}

function ReaSpeechWorker:init()
  assert(self.requests, 'missing requests')
  assert(self.responses, 'missing responses')
  assert(self.logs, 'missing logs')

  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:react()
  local time = reaper.time_precise()
  local fs = self:interval_functions()
  for i = 1, #fs do
    app:trap(function ()
      fs[i]:react(time)
    end)
  end
end

function ReaSpeechWorker:interval_functions()
  if self._interval_functions then
    return self._interval_functions
  end

  self._interval_functions = {
    IntervalFunction.new(0.3, function () self:react_handle_request() end),
    IntervalFunction.new(0.5, function () self:react_handle_jobs() end),
  }

  return self._interval_functions
end

-- Handle next request
function ReaSpeechWorker:react_handle_request()
  local request = table.remove(self.requests, 1)
  if request then
    self:handle_request(request)
  end
end

-- Make progress on jobs
function ReaSpeechWorker:react_handle_jobs()
  if self.active_job then
    self:check_active_job()
    return
  end

  local pending_job = table.remove(self.pending_jobs, 1)
  if pending_job then
    self.active_job = pending_job
    self:start_active_job()
  elseif self.job_count ~= 0 then
    app:log('Processing finished')
    self.job_count = 0
  end
end

function ReaSpeechWorker:progress()
  local job_count = self.job_count
  if job_count == 0 then
    return nil
  end

  local pending_job_count = #self.pending_jobs

  local active_job_progress = 0

  -- the active job adds 1 to the total count, and if we can know the progress
  -- then we can use that fraction
  if self.active_job then
    if self.active_job.job and self.active_job.job.progress then
      local progress = self.active_job.job.progress
      active_job_progress = (progress.current / progress.total)
    end

    pending_job_count = pending_job_count + 1
  end

  local completed_job_count = job_count + active_job_progress - pending_job_count
  return completed_job_count / job_count
end

function ReaSpeechWorker:cancel()
  if self.active_job then
    if self.active_job.job and self.active_job.job.job_id then
      self:cancel_job(self.active_job.job.job_id)
    end
    self.active_job = nil
  end
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:cancel_job(job_id)
  local url_path = "jobs/" .. job_id
  ReaSpeechAPI:fetch_json(url_path, 'DELETE', function(error_message)
    self:handle_error(self.active_job, error_message)
  end)
end

function ReaSpeechWorker:get_job_status(job_id)
  local url_path = "jobs/" .. job_id
  return ReaSpeechAPI:fetch_json(url_path, 'GET', function(error_message)
    self:handle_error(self.active_job, error_message)
    self.active_job = nil
  end)
end

function ReaSpeechWorker:handle_request(request)
  app:log('Processing speech...')
  self.job_count = #request.jobs

  local data = {
    task = request.translate and 'translate' or 'transcribe',
    output = 'json',
    use_async = 'true',
    vad_filter = 'true',
    word_timestamps = 'true',
    model_name = request.model_name,
  }

  if request.language and request.language ~= '' then
    data.language = request.language
  end

  if request.initial_prompt and request.initial_prompt ~= '' then
    data.initial_prompt = request.initial_prompt
  end

  local seen_path = {}
  for _, job in pairs(request.jobs) do
    if not seen_path[job.path] then
      seen_path[job.path] = true
      table.insert(self.pending_jobs, {job = job, data = data})
    end
  end
end

-- May return true if the job has completed and should no longer be active
function ReaSpeechWorker:handle_job_status(active_job, response)
  app:debug('Active job: ' .. dump(active_job))
  app:debug('Status: ' .. dump(response))

  if response.error then
    table.insert(self.responses, { error = response.error })
    return true
  end

  active_job.job.job_id = response.job_id

  if not response.job_status then
    return false
  end

  if response.job_status == 'SUCCESS' then
    local transcript_url_path = response.job_result.url_path
    response._job = active_job.job
    active_job.transcript_output_file, active_job.transcript_output_sentinel_file = ReaSpeechAPI:fetch_large(transcript_url_path)
    -- Job completion depends on non-blocking download of transcript
    return false
  elseif response.job_status == 'FAILURE' then
    self:handle_error(active_job, response.job_result.error)
    return true
  end

  if response.job_result and response.job_result.progress then
    active_job.job.progress = response.job_result.progress
  end

  return false
end

function ReaSpeechWorker:handle_response(active_job, response)
  response._job = active_job.job
  table.insert(self.responses, response)
end

function ReaSpeechWorker:handle_error(_active_job, error_message)
  table.insert(self.responses, { error = error_message })
end

function ReaSpeechWorker:start_active_job()
  if not self.active_job then
    return
  end

  local active_job = self.active_job
  local output_file, sentinel_file = ReaSpeechAPI:post_request('/asr', active_job.data, active_job.job.path)

  if output_file then
    active_job.request_output_file = output_file
    active_job.request_output_sentinel_file = sentinel_file
  else
    self.active_job = nil
  end
end

function ReaSpeechWorker:check_active_job()
  if not self.active_job then return end

  local active_job = self.active_job

  if active_job.request_output_file then
    self:check_active_job_request_output_file()
  end

  if active_job.transcript_output_file then
    self:check_active_job_transcript_output_file()
  else
    self:check_active_job_status()
  end
end

function ReaSpeechWorker:check_active_job_status()
  if not self.active_job then return end

  local active_job = self.active_job
  if not active_job.job.job_id then return end

  local response = self:get_job_status(active_job.job.job_id)
  if response then
    if self:handle_job_status(active_job, response) then
      self.active_job = nil
    end
  end
end

ReaSpeechWorker.check_sentinel = function(filename)
  local sentinel = io.open(filename, 'r')

  if not sentinel then
    return false
  end

  sentinel:close()
  return true
end

function ReaSpeechWorker:handle_response_json(output_file, sentinel_file, success_f, fail_f)
  if not self.check_sentinel(sentinel_file) then
    return
  end

  local f = io.open(output_file, 'r')
  if not f then
    fail_f("Couldn't open output_filename: " .. tostring(output_file))
    return
  end

  local response_text = f:read('*a')
  f:close()

  if #response_text < 1 then
    fail_f("Empty response from server.")
    return
  end

  local http_status, body = ReaSpeechAPI.http_status_and_body(response_text)

  if http_status >= 400 then
    Tempfile:remove(sentinel_file)
    Tempfile:remove(output_file)
    local msg = "Server responded with status " .. http_status
    fail_f(msg)
    app:log(msg)
    app:debug(body)
    return
  end

  local response = nil
  if app:trap(function ()
    response = json.decode(body)
  end) then
    Tempfile:remove(sentinel_file)
    Tempfile:remove(output_file)
    success_f(response)
  else
    app:debug("JSON parse error, trying again later")
  end
end

function ReaSpeechWorker:check_active_job_request_output_file()
  local active_job = self.active_job

  self:handle_response_json(
    active_job.request_output_file,
    active_job.request_output_sentinel_file,
    function(response)
      if self:handle_job_status(active_job, response) then
        self.active_job = nil
      end
    end,
    function(error_message)
      self:handle_error(active_job, error_message)
      self.active_job = nil
    end
  )
end

function ReaSpeechWorker:check_active_job_transcript_output_file()
  local active_job = self.active_job

  self:handle_response_json(
    active_job.transcript_output_file,
    active_job.transcript_output_sentinel_file,
    function(response)
      self:handle_response(active_job, response)
      self.active_job = nil
    end,
    function(error_message)
      self:handle_error(active_job, error_message)
      self.active_job = nil
    end
  )
end
