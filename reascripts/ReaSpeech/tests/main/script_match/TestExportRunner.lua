package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

require('main/script_match/export/ExportRunner')

-- Fake clock: each call advances far past the tick budget, so every
-- tick processes exactly one item and the pacing logic is observable
reaper = reaper or {}
local clock
reaper.time_precise = function()
  clock = clock + 1
  return clock
end

--

local function runner_with(items, opts, process_item)
  local outcomes = {}
  local runner = ExportRunner.new {
    process_item = process_item or function() return true end,
    on_item_done = function(item, status, error_msg)
      table.insert(outcomes, { item = item, status = status, error_msg = error_msg })
    end,
  }
  runner:start(items, opts)
  return runner, outcomes
end

TestExportRunner = {}

function TestExportRunner:setUp()
  clock = 0
end

function TestExportRunner:testEmptyQueueStaysIdle()
  local runner = runner_with({})
  lu.assertEquals(runner.state, 'idle')
  lu.assertFalse(runner:is_running())
end

function TestExportRunner:testProcessesQueueToDone()
  local runner, outcomes = runner_with({ 'a', 'b', 'c' })

  lu.assertTrue(runner:is_running())
  runner:tick()
  lu.assertEquals(runner.completed, 1)
  runner:tick()
  runner:tick()

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.succeeded, 3)
  lu.assertEquals(runner.failed, 0)
  lu.assertEquals(#outcomes, 3)
  lu.assertEquals(outcomes[1].status, 'completed')
end

function TestExportRunner:testFailureCountsAndReports()
  local runner, outcomes = runner_with({ 'good', 'bad' }, nil, function(item)
    if item == 'bad' then return false, 'no dice' end
    return true
  end)

  runner:tick()
  runner:tick()

  lu.assertEquals(runner.succeeded, 1)
  lu.assertEquals(runner.failed, 1)
  lu.assertEquals(outcomes[2].status, 'failed')
  lu.assertEquals(outcomes[2].error_msg, 'no dice')
end

-- A crashing item must not abort the batch
function TestExportRunner:testCrashCountsAsFailed()
  local runner, outcomes = runner_with({ 'boom', 'fine' }, nil, function(item)
    if item == 'boom' then error('kaput') end
    return true
  end)

  runner:tick()
  runner:tick()

  lu.assertEquals(runner.failed, 1)
  lu.assertEquals(runner.succeeded, 1)
  lu.assertEquals(outcomes[1].status, 'failed')
  lu.assertStrContains(outcomes[1].error_msg, 'kaput')
end

function TestExportRunner:testStopOnErrorAbandonsRemainder()
  local runner, outcomes = runner_with({ 'bad', 'never' }, { stop_on_error = true },
    function() return false, 'nope' end)

  runner:tick()

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.completed, 1)
  lu.assertEquals(#outcomes, 1)
end

-- The unprocessed remainder stays untouched: no outcomes reported,
-- counts stop where the cancel landed
function TestExportRunner:testCancelDropsRemainder()
  local runner, outcomes = runner_with({ 'a', 'b', 'c' })

  runner:tick()
  runner:cancel()

  lu.assertEquals(runner.state, 'done')
  lu.assertTrue(runner.cancelled)
  lu.assertEquals(runner.completed, 1)
  lu.assertEquals(#outcomes, 1)

  runner:reset()
  lu.assertEquals(runner.state, 'idle')
end

function TestExportRunner:testCancelWhenNotRunningIsANoop()
  local runner = runner_with({ 'a' })
  runner:tick()
  lu.assertEquals(runner.state, 'done')

  runner:cancel()
  lu.assertFalse(runner.cancelled)
end

--

os.exit(lu.LuaUnit.run())
