--[[

  ReaSpeechWorker.lua - Speech transcription worker

]]--

ReaSpeechWorker = Polo {}

function ReaSpeechWorker:init()
  assert(self.requests, 'missing requests')
  assert(self.responses, 'missing responses')

  Logging.init(self, 'ReaSpeechWorker')

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
    self:log('Processing finished')
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
    local active_job = self.active_job
    if active_job.initial_request and not active_job.initial_request:ready() then
      initial_request_progress = active_job.initial_request:progress()
      if initial_request_progress then
        active_job_progress = initial_request_progress / 100
      end
    elseif active_job.job and active_job.job.progress then
      local progress = active_job.job.progress
      active_job_progress = (progress.current / progress.total)
    end

    pending_job_count = pending_job_count + 1
  end

  local completed_job_count = job_count + active_job_progress - pending_job_count
  return completed_job_count / job_count
end

function ReaSpeechWorker:status()
  if self.active_job then
    local active_job = self.active_job
    if active_job.initial_request and not active_job.initial_request:ready() then
      return 'Sending Media'
    elseif active_job.job then
      return self:format_job_status(active_job.job.job_status)
    end
  end
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

function ReaSpeechWorker:format_job_status(job_status)
  if not job_status then return nil end
  local s = job_status:lower():gsub("_", " ")
  return s:gsub("(%w)(%w*)", function(first, rest)
    return first:upper() .. rest
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
  self:log('Processing speech...')
  self.job_count = #request.jobs

  for _, job in ipairs(self:expand_jobs_from_request(request)) do
    table.insert(self.pending_jobs, job)
  end
end

function ReaSpeechWorker:expand_jobs_from_request(request)
  local jobs = {}
  local seen_path = {}
  for _, job in pairs(request.jobs) do
    if not seen_path[job.path] then
      seen_path[job.path] = true
      table.insert(jobs, {
        job = job,
        endpoint = request.endpoint,
        data = request.data,
        callback = request.callback
      })
    end
  end
  return jobs
end

-- May return true if the job has completed and should no longer be active
function ReaSpeechWorker:handle_job_status(active_job, response)
  self:debug('Active job: ' .. dump(active_job))
  self:debug('Status: ' .. dump(response))

  if response.error then
    table.insert(self.responses, { error = response.error })
    return true
  end

  active_job.job.job_id = response.job_id
  active_job.job.job_status = response.job_status

  if not response.job_status then
    return false
  end

  if response.job_status == 'SUCCESS' then
    local job_result = response.job_result
    if job_result.result then
      self:handle_response(active_job, job_result.result)
      self.active_job = nil
      return false
    end

    response._job = active_job.job

    if response.job_result.url_path then
      table.insert(active_job.requests, ReaSpeechAPI:fetch_large(response.job_result.url_path))
    elseif response.job_result.url_paths then
      for _, url_path in pairs(response.job_result.url_paths) do
        table.insert(active_job.requests, function()
           ReaSpeechAPI:fetch_large(url_path)
        end)
      end
    end

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
  response.callback = active_job.callback
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
  active_job.requests = {}
  active_job.initial_request = ReaSpeechAPI:post_request(
    active_job.endpoint, active_job.data, active_job.job.path)
end

function ReaSpeechWorker:check_active_job()
  if not self.active_job then return end

  local active_job = self.active_job

  if active_job.initial_request then
    self:check_active_job_request_status()
  end

  if #active_job.requests > 0 then
    for key, request in pairs(active_job.requests) do
      if type(request) ~= 'function' then
        if not request:ready() then return end
      else
        active_job.requests[key] = request()
        return
      end
    end
    self:handle_responses()
  end

  self:check_active_job_status()
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

function ReaSpeechWorker:check_active_job_request_status()
  local active_job = self.active_job
  local request = active_job.initial_request

  if request:ready() then
    if self:handle_job_status(active_job, request:result()) then
      self.active_job = nil
    end
  elseif request:error() then
    self:handle_error(active_job, request:error())
    self.active_job = nil
  end
end

function ReaSpeechWorker:handle_responses()
  local active_job = self.active_job
  active_job.responses = {}
  for _, request in pairs(active_job.requests) do
    if request:ready() then
      table.insert(active_job.responses, request:result())
    elseif request:error() then
      self:handle_error(active_job, request:error())
      self.active_job = nil
      return
    end
  end

  self:handle_response(active_job, active_job.responses)
  self.active_job = nil
end