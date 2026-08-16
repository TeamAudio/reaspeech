--[[

  ExportRunner.lua - batch file export under a per-frame time budget

  The OneshotRunner pattern applied to export: the UI calls tick() once
  per frame while running, so a big batch slices with visible progress
  instead of freezing the interface. The runner owns pacing and counts
  only; the actual per-item work arrives as an injected callback, so
  this stays UI-free and testable.

  Cancel drops the remainder of the queue on the floor: unprocessed
  items keep whatever status they had, and the next Export picks them
  up (Export (N) already means "what isn't done yet").

]]--

ExportRunner = Polo {
  -- How much of a frame each tick may spend exporting (seconds). A
  -- single item may overrun it (one slice is atomic); the budget caps
  -- how many items pile into one frame.
  TICK_BUDGET = 0.020,
}

function ExportRunner:init()
  Logging().init(self, 'ExportRunner')

  -- process_item(item) -> success, error_msg: does one item's work
  assert(self.process_item, 'ExportRunner: process_item is required')

  -- on_item_done(item, status, error_msg): persist/report one outcome
  self.on_item_done = self.on_item_done or function() end

  self.state = 'idle' -- 'idle' | 'running' | 'done'
  self.queue = {}
  self.total = 0
  self.completed = 0
  self.succeeded = 0
  self.failed = 0
  self.cancelled = false

  self:log('Initialized ExportRunner')
end

function ExportRunner:is_running()
  return self.state == 'running'
end

-- Take on a batch. Returns the queue size (0 = nothing to do; state
-- stays idle). opts.stop_on_error: abandon the remainder after the
-- first failure (the Skip-errors-and-continue option, inverted).
function ExportRunner:start(items, opts)
  self.queue = {}
  for _, item in ipairs(items or {}) do
    table.insert(self.queue, item)
  end

  self.total = #self.queue
  self.completed = 0
  self.succeeded = 0
  self.failed = 0
  self.cancelled = false
  self.stop_on_error = opts and opts.stop_on_error or false
  self.state = self.total > 0 and 'running' or 'idle'

  self:log(('Export start: %d items queued'):format(self.total))
  return self.total
end

-- One frame's worth of exporting: process items until the time budget
-- runs out, reporting each outcome as it lands.
function ExportRunner:tick()
  if self.state ~= 'running' then return end

  local deadline = reaper.time_precise() + ExportRunner.TICK_BUDGET

  repeat
    local item = table.remove(self.queue, 1)
    if not item then break end

    -- Protected call: a crashing item must not abort the batch
    local ok, success, error_msg = pcall(self.process_item, item)
    if not ok then
      success, error_msg = false, tostring(success)
    end

    self.completed = self.completed + 1
    if success then
      self.succeeded = self.succeeded + 1
    else
      self.failed = self.failed + 1
      self:log('Export failed: ' .. tostring(error_msg or 'unknown'))
    end

    self.on_item_done(item, success and 'completed' or 'failed', error_msg)

    if not success and self.stop_on_error then
      self:log('Stopping at first error (Skip errors and continue is off)')
      self.queue = {}
    end
  until reaper.time_precise() >= deadline

  if #self.queue == 0 then
    self.state = 'done'
    self:log(('Export done: %d succeeded, %d failed of %d'):format(
      self.succeeded, self.failed, self.total))
  end
end

-- Stop now; the unprocessed remainder stays pending for a later Export
function ExportRunner:cancel()
  if self.state ~= 'running' then return end

  self.cancelled = true
  self.queue = {}
  self.state = 'done'
  self:log(('Export cancelled: %d of %d processed'):format(self.completed, self.total))
end

-- Acknowledge completion (the UI reads the counts, then calls this)
function ExportRunner:reset()
  self.state = 'idle'
  self.queue = {}
end
