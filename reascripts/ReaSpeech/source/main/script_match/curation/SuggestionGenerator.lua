SuggestionGenerator = Polo {}

function SuggestionGenerator:init()
  Logging().init(self, 'SuggestionGenerator')

  assert(self.session_id, 'SuggestionGenerator: session_id is required')
  assert(self.needle, 'SuggestionGenerator: needle is required')
  assert(self.workflow, 'SuggestionGenerator: workflow is required')

  -- Store callback functions for workflow registration pattern (with no-op defaults)
  self.on_status_change = self.on_status_change or function() end
  self.on_completion = self.on_completion or function() end
  self.on_error = self.on_error or function() end

  self.matching_engine = MatchingEngine.new {
    session_id = self.session_id,
    workflow = self.workflow,
  }

  -- Async job tracking fields
  self.async_request = nil
  self.job_id = nil
  self.status = 'idle' -- 'idle', 'pending', 'running', 'completed', 'error'
  self.results = nil
  self.error_message = nil

  -- Internal polling interval and workflow registration
  self.polling_interval = nil
  self.registered_with_workflow = false

  self:log("Initialized SuggestionGenerator")
end


-- Start async suggestion generation via MatchingEngine
-- Updated to use MatchingEngine async coordination instead of direct API calls
-- Register with workflow for timing and create internal polling interval
function SuggestionGenerator:start_async_generation()
  if self.status ~= 'idle' and self.status ~= 'completed' and self.status ~= 'error' then
    self:log("Cannot start generation - job already in progress (status: " .. self.status .. ")")
    return false
  end

  self:log("Starting async suggestion generation for needle: " .. self.needle.content)

  -- Reset state
  self.async_request = nil
  self.job_id = nil
  self.results = nil
  self.error_message = nil
  self.status = 'pending'

  -- Create internal polling interval
  self.polling_interval = IntervalFunction().new(0.3, function()
    self:poll_and_callback()
  end)

  -- Register with workflow for timing
  local stop_check = function()
    return self.status == 'completed' or self.status == 'error' or self.status == 'idle'
  end

  self.workflow:register_nudgeable(self.polling_interval, stop_check)
  self.registered_with_workflow = true
  self:log("Registered polling interval with workflow")

  -- Delegate to MatchingEngine for multi-matcher coordination
  local engine_started = self.matching_engine:start_async_matching(self.needle)
  if engine_started then
    self.status = 'running'
    self:log("Successfully started async matching engine")

    -- Invoke status change callback
    self.on_status_change(self.status)

    return true
  else
    self.status = 'error'
    self.error_message = "Failed to start matching engine"
    self:log("ERROR: " .. self.error_message)

    -- Invoke error callback
    self.on_error(self.error_message)

    return false
  end
end

-- Internal polling method that checks status and invokes callbacks
function SuggestionGenerator:poll_and_callback()
  local previous_status = self.status

  -- Check if job is ready using existing is_ready logic
  if not self:is_ready() then
    -- Still running, no callback needed unless status changed
    if previous_status ~= self.status then
      self.on_status_change(self.status)
    end
    return
  end

  -- Job is ready (completed or error)
  if self.status == 'completed' then
    self:log("Suggestion generation completed via callback")
    self.on_completion(self.results)
  elseif self.status == 'error' then
    self:log("Suggestion generation error via callback: " .. (self.error_message or "Unknown error"))
    self.on_error(self.error_message)
  end

  -- Invoke status change callback if status changed
  if previous_status ~= self.status then
    self.on_status_change(self.status)
  end
end

-- Check if async job is ready (completed or errored)
-- Updated to check MatchingEngine status instead of direct API polling
function SuggestionGenerator:is_ready()
  if self.status == 'idle' or self.status == 'error' then
    return true
  end

  if self.status == 'completed' then
    return true
  end

  -- Check MatchingEngine status
  if self.matching_engine:is_ready() then
    if self.matching_engine:has_error() then
      self.status = 'error'
      self.error_message = "MatchingEngine error: " .. (self.matching_engine.async_error_message or "Unknown error")
      self:log("ERROR: " .. self.error_message)
    else
      self.status = 'completed'
      -- Get results from MatchingEngine
      local results, error_msg = self.matching_engine:get_results()
      if results then
        self.results = results
        self:log("Successfully completed with " .. #results .. " suggestions")
      else
        self.status = 'error'
        self.error_message = error_msg or "Failed to get results from MatchingEngine"
        self:log("ERROR: " .. self.error_message)
      end
    end
    return true
  end

  -- Still running
  return false
end

-- Get results from completed async job
function SuggestionGenerator:get_results()
  if self.status == 'completed' then
    return self.results
  elseif self.status == 'error' then
    return nil, self.error_message
  else
    return nil, "Job not ready (status: " .. self.status .. ")"
  end
end

-- Check if async job has encountered an error
function SuggestionGenerator:has_error()
  return self.status == 'error'
end

-- Get current job status
function SuggestionGenerator:get_status()
  return self.status
end

-- Cancel ongoing async job
-- Updated to cancel MatchingEngine jobs
-- Clean up workflow registration and internal polling
function SuggestionGenerator:cancel()
  if self.status == 'pending' or self.status == 'running' then
    self:log("Cancelling suggestion generation job")

    -- Cancel all matcher jobs via MatchingEngine
    local cancelled = self.matching_engine:cancel()

    -- Clean up workflow registration and polling
    self.polling_interval = nil
    self.registered_with_workflow = false

    self.status = 'idle'
    self.async_request = nil
    self.job_id = nil
    self.results = nil
    self.error_message = nil

    self:log("Cancelled suggestion generation" .. (cancelled and " (MatchingEngine cancelled)" or " (MatchingEngine not cancelled)"))
    return true
  end
  return false
end
