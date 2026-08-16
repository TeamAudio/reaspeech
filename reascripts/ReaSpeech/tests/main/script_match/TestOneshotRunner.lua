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

local now = 0
reaper = {
  time_precise = function() return now end,
  genGuid = function() return '{GUID}' end,
}

-- The runner builds its matcher through this global; tests supply a
-- scripted double instead of the real FuzzyWordMatcher
FuzzyWordMatcher = {
  new = function()
    return {
      name = function() return 'Test Matcher' end,
      match = function(_self, needle)
        if needle.explode then error('boom') end
        local suggestions = {}
        for i = 1, (needle.matches or 0) do
          table.insert(suggestions, {
            start_time = i,
            end_time = i + 1,
            confidence = needle.confidences and needle.confidences[i] or 0.9,
            long_shot = needle.long_shot,
          })
        end
        return suggestions
      end,
    }
  end,
}

require('main/script_match/curation/OneshotRunner')

-- Optional diagnosis double: records diagnose/clear calls
local function make_diagnosis_double()
  return {
    diagnosed = {},
    cleared = {},
    refreshed = 0,
    refresh_candidates = function(self) self.refreshed = self.refreshed + 1 end,
    diagnose = function(self, needle)
      table.insert(self.diagnosed, needle)
      return { class = 'not_recorded' }
    end,
    clear = function(self, locator) table.insert(self.cleared, locator) end,
  }
end

local function make_runner(already_suggested, diagnosis)
  local persisted = {}
  local events = {}
  local decisions = {}

  local state_manager = {
    get_needles_with_suggestions = function()
      local entries = {}
      for _, guid in ipairs(already_suggested or {}) do
        table.insert(entries, { needle_guid = guid, count = 5 })
      end
      -- An earlier roll that found nothing: does NOT count as suggested
      table.insert(entries, { needle_guid = 'EMPTY-ROLL', count = 0 })
      return entries
    end,
    -- Mimics the real persist: fresh suggestions come back with a guid
    -- and pending state
    persist_generated = function(_self, needle_guid, suggestions)
      for i, suggestion in ipairs(suggestions) do
        suggestion.guid = needle_guid .. '-' .. i
        suggestion.state = suggestion.state or 'pending'
      end
      persisted[needle_guid] = suggestions
      return suggestions
    end,
    record_decision = function(_self, needle_guid, suggestion_guid, action)
      table.insert(decisions, {
        needle_guid = needle_guid,
        suggestion_guid = suggestion_guid,
        action = action,
      })
      for _, suggestion in ipairs(persisted[needle_guid] or {}) do
        if suggestion.guid == suggestion_guid then
          suggestion.state = action
          return suggestion
        end
      end
    end,
    get_suggestion_summary = function(_self, needle_guid)
      local summary = { total = 0, accepted = 0, rejected = 0, pending = 0 }
      for _, suggestion in ipairs(persisted[needle_guid] or {}) do
        summary.total = summary.total + 1
        summary[suggestion.state] = (summary[suggestion.state] or 0) + 1
      end
      return summary
    end,
  }

  local workflow = {
    get_matcher_stream_cache = function() return {} end,
    get_suggestion_state_manager = function() return state_manager end,
    emit_event = function(_self, name, data)
      table.insert(events, { name = name, data = data })
    end,
  }
  if diagnosis then
    workflow.get_needle_diagnosis = function() return diagnosis end
  end

  local runner = OneshotRunner.new { session_id = 'S', workflow = workflow }
  return runner, persisted, events, decisions
end

local function tick_until_done(runner, max_ticks)
  for _ = 1, (max_ticks or 100) do
    if runner.state ~= 'rolling' then break end
    runner:tick()
  end
end

--

TestOneshotRunner = {}

function TestOneshotRunner:testSkipsNeedlesWithSuggestions()
  local runner = make_runner({ 'N1' })
  local queued = runner:start({ { guid = 'N1' }, { guid = 'N2', matches = 2 } })
  lu.assertEquals(queued, 1)
  lu.assertEquals(runner.total, 1)
end

function TestOneshotRunner:testEmptyPreviousRollGetsRerolled()
  local runner = make_runner({ 'N1' })
  local queued = runner:start({ { guid = 'N1' }, { guid = 'EMPTY-ROLL', matches = 1 } })
  lu.assertEquals(queued, 1)
end

function TestOneshotRunner:testNothingToDoStaysIdle()
  local runner = make_runner({ 'N1' })
  local queued = runner:start({ { guid = 'N1' } })
  lu.assertEquals(queued, 0)
  lu.assertEquals(runner.state, 'idle')
end

function TestOneshotRunner:testRollsPersistsAndAnnounces()
  local runner, persisted, events = make_runner()
  runner:start({ { guid = 'N1', matches = 2 }, { guid = 'N2', matches = 1 } })

  tick_until_done(runner)

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.completed, 2)
  lu.assertEquals(runner.takes_found, 3)
  lu.assertEquals(#persisted.N1, 2)
  lu.assertEquals(#persisted.N2, 1)

  -- Matcher-context enrichment applied before persisting
  lu.assertEquals(persisted.N1[1].matcher_name, 'Test Matcher')
  lu.assertEquals(persisted.N1[1].needle.guid, 'N1')

  lu.assertEquals(#events, 2)
  lu.assertEquals(events[1].name, 'suggestions_generated')
  lu.assertEquals(events[1].data.needle_id, 'N1')
end

function TestOneshotRunner:testMatcherErrorCountsAsCompleted()
  local runner, persisted = make_runner()
  runner:start({ { guid = 'N1', explode = true }, { guid = 'N2', matches = 1 } })

  tick_until_done(runner)

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.completed, 2)
  lu.assertEquals(runner.takes_found, 1)
  lu.assertEquals(persisted.N1, {})
end

function TestOneshotRunner:testThresholdForRiskMapping()
  lu.assertEquals(OneshotRunner.threshold_for_risk(nil), nil)
  lu.assertEquals(OneshotRunner.threshold_for_risk(0), nil)
  lu.assertEquals(OneshotRunner.threshold_for_risk(1), 0.75)
  lu.assertEquals(OneshotRunner.threshold_for_risk(0.5), 0.875)
  -- Out-of-range positions clamp to the full-dice floor
  lu.assertEquals(OneshotRunner.threshold_for_risk(2), 0.75)
end

function TestOneshotRunner:testNoThresholdMeansNoDecisions()
  local runner, _, _, decisions = make_runner()
  runner:start({ { guid = 'N1', matches = 2 } })
  tick_until_done(runner)

  lu.assertEquals(#decisions, 0)
  lu.assertEquals(runner.auto_accepted, 0)
end

function TestOneshotRunner:testAutoAcceptsAboveThreshold()
  local runner, persisted, events, decisions = make_runner()
  runner:start(
    { { guid = 'N1', matches = 3, confidences = { 0.95, 0.9, 0.6 } } },
    { auto_accept_threshold = 0.875 })

  tick_until_done(runner)

  lu.assertEquals(#decisions, 2)
  lu.assertEquals(decisions[1].action, 'accepted')
  lu.assertEquals(runner.auto_accepted, 2)
  lu.assertEquals(persisted.N1[1].state, 'accepted')
  lu.assertEquals(persisted.N1[2].state, 'accepted')
  lu.assertEquals(persisted.N1[3].state, 'pending')

  -- suggestions_generated first, then one suggestion_decided per accept
  lu.assertEquals(#events, 3)
  lu.assertEquals(events[1].name, 'suggestions_generated')
  lu.assertEquals(events[2].name, 'suggestion_decided')
  lu.assertEquals(events[2].data.action, 'accepted')
  lu.assertEquals(events[2].data.needle_id, 'N1')
  lu.assertEquals(events[2].data.summary.accepted, 2)
  lu.assertEquals(events[3].data.suggestion_id, 'N1-2')
end

function TestOneshotRunner:testLongShotsNeverAutoAccept()
  local runner, persisted, _, decisions = make_runner()
  runner:start(
    { { guid = 'N1', matches = 1, confidences = { 0.95 }, long_shot = true } },
    { auto_accept_threshold = 0.75 })

  tick_until_done(runner)

  lu.assertEquals(#decisions, 0)
  lu.assertEquals(runner.auto_accepted, 0)
  lu.assertEquals(persisted.N1[1].state, 'pending')
end

function TestOneshotRunner:testResetReturnsToIdle()
  local runner = make_runner()
  runner:start({ { guid = 'N1' } })
  tick_until_done(runner)
  runner:reset()
  lu.assertEquals(runner.state, 'idle')
end

-- The diagnosis pass: empties get a verdict after the matching queue
-- drains; rolls that found something clear any stale verdict
function TestOneshotRunner:testDiagnosesEmptyRollsAfterMatching()
  local diagnosis = make_diagnosis_double()
  local runner, _, events = make_runner(nil, diagnosis)

  runner:start({
    { guid = 'A', locator = 'L-A', matches = 0 },
    { guid = 'B', locator = 'L-B', matches = 2 },
  })
  tick_until_done(runner)

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.diagnosed, 1)
  lu.assertEquals(#diagnosis.diagnosed, 1)
  lu.assertEquals(diagnosis.diagnosed[1].guid, 'A')
  lu.assertEquals(diagnosis.cleared, { 'L-B' })
  lu.assertEquals(diagnosis.refreshed, 1)

  local diagnosed_events = 0
  for _, event in ipairs(events) do
    if event.name == 'needle_diagnosed' then
      diagnosed_events = diagnosed_events + 1
      lu.assertEquals(event.data.locator, 'L-A')
      lu.assertEquals(event.data.verdict.class, 'not_recorded')
    end
  end
  lu.assertEquals(diagnosed_events, 1)
end

-- Without a diagnosis service (older doubles), the runner still
-- completes cleanly
function TestOneshotRunner:testNoDiagnosisServiceStillCompletes()
  local runner = make_runner()
  runner:start({ { guid = 'A', matches = 0 } })
  tick_until_done(runner)

  lu.assertEquals(runner.state, 'done')
  lu.assertEquals(runner.diagnosed, 0)
end

--

os.exit(lu.LuaUnit.run())
