--[[

  ReaSpeechWorker.lua - Speech transcription worker

]]--

ReaSpeechWorker = {}

ReaSpeechWorker.__index = ReaSpeechWorker
ReaSpeechWorker.new = function (o)
  o = o or {}
  setmetatable(o, ReaSpeechWorker)
  o:init()
  return o
end

function ReaSpeechWorker:init()
  assert(self.requests, 'missing requests')
  assert(self.responses, 'missing responses')
  assert(self.logs, 'missing logs')
  assert(self.asr_url, 'missing asr_url')

  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:react()
  for _, handler in pairs(self:react_handlers()) do
    app:trap(handler)
  end
end

function ReaSpeechWorker:react_handlers()
  return {
    self:react_handle_interval_functions(),
  }
end

-- Handle next request
function ReaSpeechWorker:react_handle_request()
  return IntervalFunction.new(0.3, function()
    -- Handle next request
    local request = table.remove(self.requests, 1)
    if request then
      self:handle_request(request)
    end
  end)
end

-- Make progress on jobs
function ReaSpeechWorker:react_handle_jobs()
  return IntervalFunction.new(0.5, function()
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
  end)
end

function ReaSpeechWorker:react_handle_interval_functions()
  return function()
    local time = reaper.time_precise()
    local fs = self:interval_functions()
    for i = 1, #fs do
      fs[i]:react(time)
    end
  end
end

function ReaSpeechWorker:interval_functions()
  if self._interval_functions then
    return self._interval_functions
  end

  self._interval_functions = {
    self:react_handle_request(),
    self:react_handle_jobs(),
  }

  return self._interval_functions
end

function ReaSpeechWorker:progress()
  local job_count = self.job_count
  if job_count == 0 then
    return nil
  end
  local pending_job_count = #self.pending_jobs
  if self.active_job then
    pending_job_count = pending_job_count + 1
  end
  local completed_job_count = job_count - pending_job_count
  return completed_job_count / job_count
end

function ReaSpeechWorker:cancel()
  self.active_job = nil
  self.pending_jobs = {}
  self.job_count = 0
end

function ReaSpeechWorker:handle_request(request)
  app:log('Processing speech...')
  self.job_count = #request.jobs

  local data = {
    task = request.translate and 'translate' or 'transcribe',
    output = 'json',
    vad_filter = 'true',
    word_timestamps = 'true',
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

      if request.use_job_queue then
        job.use_job_queue = true
      end

      table.insert(self.pending_jobs, {job = job, data = data})
    end
  end
end

function ReaSpeechWorker:handle_response(active_job, response)
  app:debug('Active job: ' .. dump(active_job))
  app:debug('Response: ' .. dump(response))

  if not ReaSpeechWorker.is_async_job(active_job.job) then
    response._job = active_job.job
    table.insert(self.responses, response)
    return true
  end

  if not response.job_status or response.job_status == 'PENDING' then
    active_job.job.job_id = response.job_id
    return false
  end

  if response.job_status == 'SUCCESS' then
    local transcript_url_path = response.job_result.url
    response._job = active_job.job
    local transcript = self:fetch_json(transcript_url_path)
    transcript._job = active_job.job
    table.insert(self.responses, transcript)
    return true
  end

  -- We should handle some failure cases here
end

function ReaSpeechWorker:start_active_job()
  if not self.active_job then
    return
  end

  local active_job = self.active_job

  local remote_url = nil
  if active_job.job.use_job_queue then
    remote_url = table.concat({"http://", Script.host, "/transcribe"}, "")
  end

  local output_file = self:post_request(active_job.data, active_job.job.path, remote_url)

  if output_file then
    active_job.output_file = output_file
  else
    self.active_job = nil
  end
end

function ReaSpeechWorker:check_active_job()
  if not (self.active_job and self.active_job.output_file) then
    return
  end

  local job = self.active_job.job

  if ReaSpeechWorker.is_async_job(job) and job.job_id then
    self:check_active_job_async()
  else
    self:check_active_job_output_file()
  end
end

function ReaSpeechWorker.is_async_job(job)
  return job.use_job_queue
end

function ReaSpeechWorker:check_active_job_async()
  local active_job = self.active_job

  local response = self:get_job_status(active_job.job.job_id)

  if response then
    if self:handle_response(active_job, response) then
      self.active_job = nil
    end
  end
end

function ReaSpeechWorker:check_active_job_output_file()
  local active_job = self.active_job
  local output_file = active_job.output_file

  local f = io.open(output_file, 'r')
  if f then
    local response_text = f:read('*a')
    f:close()

    if #response_text > 0 then
      local response = nil
      if app:trap(function ()
        response = json.decode(response_text)
      end) then
        Tempfile:remove(output_file)
        if self:handle_response(active_job, response) then
          self.active_job = nil
        end
      else
        app:debug("JSON parse error, trying again later")
      end
    end
  end
end

function ReaSpeechWorker:fetch_json(url_path)
  local curl = ReaSpeechWorker.get_curl_cmd()
  local url = ("http://%s%s"):format(Script.host, url.quote(url_path))
  local command = (
    curl
    .. ' "' .. url .. '"'
    .. ' -H "accept: application/json"'
    .. ' -s'
  )

  local exec_result = reaper.ExecProcess(command, 0)

  if exec_result == nil then
    return nil
  end

  local _, output = exec_result:match("(%d+)\n(.*)")

  local response_json = nil
  if app:trap(function()
    response_json = json.decode(output)
  end) then
    return response_json
  else
    app:log("JSON parse error")
    app:log(output)
    return nil
  end
end

function ReaSpeechWorker.get_curl_cmd()
  local curl = "curl"
  if not reaper.GetOS():find("Win") then
    curl = "/usr/bin/curl"
  end
  return curl
end

function ReaSpeechWorker:get_job_status(job_id)
  local url_path = "/jobs/" .. job_id
  return self:fetch_json(url_path)
end

function ReaSpeechWorker:post_request(data, path, remote_url)
  remote_url = remote_url or self.asr_url
  local curl = ReaSpeechWorker.get_curl_cmd()
  local query = {}
  for k, v in pairs(data) do
    table.insert(query, k .. '=' .. url.quote(v))
  end
  local output_file = Tempfile:name()
  local command = (
    curl
    .. ' "' .. remote_url .. '?' .. table.concat(query, '&') .. '"'
    .. ' -H "accept: application/json"'
    .. ' -H "Content-Type: multipart/form-data"'
    .. ' -F ' .. self:_maybe_quote('audio_file=@"' .. path .. '"')
    .. ' -o "' .. output_file .. '"'
  )
  app:log(path)
  app:debug('Command: ' .. command)
  if reaper.ExecProcess(command, -2) then
    return output_file
  else
    app:log("Unable to run curl")
    return nil
  end
end

function ReaSpeechWorker:_maybe_quote(arg)
  if reaper.GetOS():find("Win") then
    return arg
  else
    return "'" .. arg .. "'"
  end
end
