MatchingEngine = Polo {}

function MatchingEngine:init()
  Logging().init(self, 'MatchingEngine')

  assert(self.session_id, 'MatchingEngine: session_id is required')
  assert(self.workflow, 'MatchingEngine: workflow is required')

  self.matchers = {
    FuzzyWordMatcher.new {
      session_id = self.session_id,
      workflow = self.workflow,
      stream_cache = self.workflow:get_matcher_stream_cache(),
    }
  }

  -- Add async job coordination state
  self.async_jobs = {}        -- Track jobs per matcher
  self.async_status = 'idle'  -- Overall status: idle, pending, running, completed, error
  self.async_needle = nil     -- Current needle being processed
  self.async_results = {}     -- Aggregated results from all matchers
  self.async_error_message = nil

  self:log("Initialized MatchingEngine with " .. #self.matchers .. " matchers")
end


-- Enhanced async matching with multi-matcher coordination
function MatchingEngine:start_async_matching(needle)
  if self.async_status ~= 'idle' and self.async_status ~= 'completed' and self.async_status ~= 'error' then
    self:log("Cannot start async matching - jobs already in progress (status: " .. self.async_status .. ")")
    return false
  end

  self:log("Starting async matching with " .. #self.matchers .. " matchers for needle: " .. needle.content)

  -- Reset async state
  self.async_jobs = {}
  self.async_status = 'pending'
  self.async_needle = needle
  self.async_results = {}
  self.async_error_message = nil

  -- Start async jobs for all registered matchers
  local jobs_started = 0
  for i, matcher in ipairs(self.matchers) do
    self:log("Starting async job for matcher: " .. matcher:name())

    local job_started = matcher:start_async_generation(needle)
    if job_started then
      self.async_jobs[i] = {
        matcher = matcher,
        status = 'pending',
        results = nil,
        error_message = nil
      }
      jobs_started = jobs_started + 1
    else
      self:log("ERROR: Failed to start job for matcher: " .. matcher:name())
      self.async_jobs[i] = {
        matcher = matcher,
        status = 'error',
        results = nil,
        error_message = "Failed to start async job"
      }
    end
  end

  if jobs_started > 0 then
    self.async_status = 'running'
    self:log("Successfully started " .. jobs_started .. " async matcher jobs")
    return true
  else
    self.async_status = 'error'
    self.async_error_message = "Failed to start any matcher jobs"
    self:log("ERROR: " .. self.async_error_message)
    return false
  end
end

-- Check if all async jobs are ready (completed or errored)
function MatchingEngine:is_ready()
  if self.async_status == 'idle' or self.async_status == 'completed' or self.async_status == 'error' then
    return true
  end

  -- Check status of all matcher jobs
  local completed_jobs = 0
  local error_jobs = 0
  local total_jobs = 0

  for _, job in pairs(self.async_jobs) do
    total_jobs = total_jobs + 1
    local matcher = job.matcher

    -- Update job status based on matcher state
    if matcher:has_error() then
      if job.status ~= 'error' then
        job.status = 'error'
        job.error_message = "Matcher error: " .. (matcher.async_error_message or "Unknown error")
        self:log("Matcher " .. matcher:name() .. " failed: " .. job.error_message)
      end
      error_jobs = error_jobs + 1
    elseif matcher:is_ready() then
      if job.status ~= 'completed' then
        job.status = 'completed'
        -- Get results from completed matcher
        local results, error_msg = matcher:get_results()
        if results then
          job.results = results
          self:log("Matcher " .. matcher:name() .. " completed with " .. #results .. " suggestions")
        else
          job.status = 'error'
          job.error_message = error_msg or "Failed to get results"
          self:log("ERROR: Matcher " .. matcher:name() .. " completed but failed to get results: " .. job.error_message)
          error_jobs = error_jobs + 1
        end
      end
      if job.status == 'completed' then
        completed_jobs = completed_jobs + 1
      end
    else
      -- Job still running
      job.status = 'running'
    end
  end

  -- Determine overall status
  if completed_jobs + error_jobs >= total_jobs then
    -- All jobs finished (either completed or errored)
    if completed_jobs > 0 then
      self.async_status = 'completed'
      self:_aggregate_results()
      self:log("All matcher jobs finished - " .. completed_jobs .. " completed, " .. error_jobs .. " errored")
    else
      self.async_status = 'error'
      self.async_error_message = "All matcher jobs failed"
      self:log("ERROR: All matcher jobs failed")
    end
    return true
  end

  -- Some jobs still running
  return false
end

-- Get aggregated results from all completed matchers
function MatchingEngine:get_results()
  if self.async_status == 'completed' then
    return self.async_results
  elseif self.async_status == 'error' then
    return nil, self.async_error_message
  else
    return nil, "Matching not ready (status: " .. (self.async_status or 'uninitialized') .. ")"
  end
end

-- Check if any matcher jobs have encountered errors
function MatchingEngine:has_error()
  return self.async_status == 'error'
end

-- Get current overall status
function MatchingEngine:get_status()
  return self.async_status or 'idle'
end

-- Cancel all ongoing matcher jobs
function MatchingEngine:cancel()
  if self.async_status == 'pending' or self.async_status == 'running' then
    self:log("Cancelling all async matcher jobs")

    local cancelled_count = 0
    for _, job in pairs(self.async_jobs) do
      if job.status == 'pending' or job.status == 'running' then
        local cancelled = job.matcher:cancel()
        if cancelled then
          job.status = 'cancelled'
          cancelled_count = cancelled_count + 1
        end
      end
    end

    self.async_status = 'idle'
    self.async_jobs = {}
    self.async_results = {}
    self.async_error_message = nil

    self:log("Cancelled " .. cancelled_count .. " matcher jobs")
    return true
  end
  return false
end

-- Internal method to aggregate results from all completed matchers
function MatchingEngine:_aggregate_results()
  local aggregated = {}
  local total_suggestions = 0

  for _, job in pairs(self.async_jobs) do
    if job.status == 'completed' and job.results then
      for _, suggestion in ipairs(job.results) do
        -- Enrich suggestion with needle and matcher info
        suggestion.needle = self.async_needle
        suggestion.matcher_name = job.matcher:name()
        table.insert(aggregated, suggestion)
        total_suggestions = total_suggestions + 1
      end
    end
  end

  -- Sort by confidence (highest first)
  table.sort(aggregated, function(a, b)
    return (a.confidence or 0) > (b.confidence or 0)
  end)

  self.async_results = aggregated
  self:log("Aggregated " .. total_suggestions .. " suggestions from " .. self:_count_completed_jobs() .. " matchers")
end

-- Helper method to count completed jobs for logging
function MatchingEngine:_count_completed_jobs()
  local count = 0
  for _, job in pairs(self.async_jobs) do
    if job.status == 'completed' then
      count = count + 1
    end
  end
  return count
end