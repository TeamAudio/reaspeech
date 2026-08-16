--[[

  OneshotRunner.lua - batch-match every needle in one GO

  Drives the synchronous matcher core directly (FuzzyWordMatcher:match)
  under a per-frame time budget: the UI calls tick() once per frame
  while rolling, so a 118-line session fills in a couple of seconds of
  visible progress without freezing the interface. Results persist
  through the same SuggestionStateManager path the curation card uses.

  The risk slider (v2) adds auto-accept: suggestions whose confidence
  clears the slider's threshold are accepted as they land, so full dice
  rolls the session straight from setup toward export. Comb end keeps
  the v1 behavior - everything generated, every decision human.

]]--

OneshotRunner = Polo {
  -- How much of a frame each tick may spend matching (seconds)
  TICK_BUDGET = 0.020,

  -- Auto-accept threshold at full dice. Reference sessions average
  -- ~0.94 confidence on true matches; 0.75 accepts what the odds favor
  -- while staying above the long-shot floor.
  MAX_RISK_THRESHOLD = 0.75,
}

-- Map the GO band's risk slider (0 = comb, 1 = dice) to an auto-accept
-- confidence threshold. The comb end means no auto-accept at all (nil);
-- past it, the threshold slides from "only perfect matches" down to
-- the full-dice floor.
function OneshotRunner.threshold_for_risk(risk)
  if not risk or risk <= 0 then return nil end
  if risk > 1 then risk = 1 end
  return 1.0 - risk * (1.0 - OneshotRunner.MAX_RISK_THRESHOLD)
end

function OneshotRunner:init()
  Logging().init(self, 'OneshotRunner')

  assert(self.session_id, 'OneshotRunner: session_id is required')
  assert(self.workflow, 'OneshotRunner: workflow is required')

  self.matcher = FuzzyWordMatcher.new {
    session_id = self.session_id,
    workflow = self.workflow,
    stream_cache = self.workflow:get_matcher_stream_cache(),
  }

  self.state = 'idle' -- 'idle' | 'rolling' | 'done'
  self.queue = {}
  self.total = 0
  self.completed = 0
  self.takes_found = 0
  self.auto_accepted = 0
  self.auto_accept_threshold = nil

  -- Needles whose roll came up empty queue for the diagnosis pass
  -- (the WHY: unlinked track, never recorded, non-verbal)
  self.diagnosis_queue = {}
  self.diagnosed = 0

  self:log('Initialized OneshotRunner')
end

-- The workflow-owned diagnosis service, when available (test doubles
-- may not carry it; the runner then skips the diagnosis pass)
function OneshotRunner:get_diagnosis()
  if self.workflow.get_needle_diagnosis then
    return self.workflow:get_needle_diagnosis()
  end
end

function OneshotRunner:is_diagnosing()
  return self.state == 'rolling' and #self.queue == 0 and #self.diagnosis_queue > 0
end

function OneshotRunner:is_rolling()
  return self.state == 'rolling'
end

-- Queue every needle that has no suggestions yet. A needle whose
-- previous roll came up EMPTY still counts as unsuggested - GO should
-- keep trying those (the long-shot tier may catch them now). Returns
-- the queue size (0 = nothing to do; state stays idle).
-- opts.auto_accept_threshold: confidence at or above which fresh
-- suggestions are accepted as they land (nil = no auto-accept).
function OneshotRunner:start(needles, opts)
  local suggested = {}
  for _, entry in ipairs(self.workflow:get_suggestion_state_manager():get_needles_with_suggestions()) do
    if entry.needle_guid and (entry.count or 0) > 0 then
      suggested[entry.needle_guid] = true
    end
  end

  -- The full script-ordered list and an index into it: gap inference
  -- reasons from a straggler's neighbors
  self.all_needles = needles or {}
  self.needle_index_by_guid = {}
  for i, needle in ipairs(self.all_needles) do
    if needle.guid then
      self.needle_index_by_guid[needle.guid] = i
    end
  end

  self.queue = {}
  for _, needle in ipairs(needles or {}) do
    if needle.guid and not suggested[needle.guid] then
      table.insert(self.queue, needle)
    end
  end

  self.total = #self.queue
  self.completed = 0
  self.takes_found = 0
  self.auto_accepted = 0
  self.auto_accept_threshold = opts and opts.auto_accept_threshold or nil
  self.diagnosis_queue = {}
  self.diagnosed = 0
  self.state = self.total > 0 and 'rolling' or 'idle'

  -- Tracks may have been linked since the last roll; the candidate
  -- list must reflect today's session
  local diagnosis = self:get_diagnosis()
  if diagnosis then
    diagnosis:refresh_candidates()
  end

  self:log(('Oneshot start: %d of %d needles to match'):format(self.total, #(needles or {})))
  return self.total
end

-- One frame's worth of matching: process needles until the time budget
-- runs out, persisting and announcing each needle's results as it lands.
function OneshotRunner:tick()
  if self.state ~= 'rolling' then return end

  local state_manager = self.workflow:get_suggestion_state_manager()
  local deadline = reaper.time_precise() + OneshotRunner.TICK_BUDGET

  repeat
    local needle = table.remove(self.queue, 1)
    if not needle then break end

    self:tick_matching(needle, state_manager)
  until reaper.time_precise() >= deadline

  -- Second phase, same budget: diagnose the empties (the matching
  -- queue must fully drain first - a long-shot landing late would
  -- outdate an early verdict)
  if #self.queue == 0 then
    local diagnosis = self:get_diagnosis()
    while diagnosis and #self.diagnosis_queue > 0
      and reaper.time_precise() < deadline do
      self:tick_diagnosis(diagnosis)
    end

    if not diagnosis then
      self.diagnosis_queue = {}
    end
  end

  if #self.queue == 0 and #self.diagnosis_queue == 0 then
    self.state = 'done'
    self:log(('Oneshot done: %d needles, %d takes, %d auto-accepted, %d diagnosed'):format(
      self.completed, self.takes_found, self.auto_accepted, self.diagnosed))
  end
end

-- Script-order context for the matcher's gap-inference tier: only
-- available when the workflow carries the claims service
function OneshotRunner:match_context(needle)
  if not self.workflow.get_claimed_spans then return nil end

  local index = self.needle_index_by_guid[needle.guid]
  if not index then return nil end

  local window = GapInference.window_for(
    self.all_needles, index, self.workflow:get_claimed_spans():by_needle())
  return window and { gap_window = window } or nil
end

function OneshotRunner:tick_matching(needle, state_manager)

    local ok, suggestions = pcall(self.matcher.match, self.matcher, needle, self:match_context(needle))
    if not ok then
      self:log('Oneshot matching failed for needle ' .. tostring(needle.guid) .. ': ' .. tostring(suggestions))
      suggestions = {}
    end

    -- Same enrichment MatchingEngine applies before the card persists
    for _, suggestion in ipairs(suggestions) do
      suggestion.needle = needle
      suggestion.matcher_name = self.matcher:name()
    end

    local persisted = {}
    local persist_ok, persist_result = pcall(function()
      return state_manager:persist_generated(needle.guid, suggestions)
    end)
    if persist_ok then
      persisted = persist_result
    else
      self:log('Oneshot persist failed for needle ' .. tostring(needle.guid) .. ': ' .. tostring(persist_result))
    end

    self.takes_found = self.takes_found + #persisted
    self.completed = self.completed + 1

    local accepted = self:auto_accept(needle.guid, persisted)

    self.workflow:emit_event('suggestions_generated', {
      needle_id = needle.guid,
      suggestions = persisted,
    })

    if #accepted > 0 then
      local summary = state_manager:get_suggestion_summary(needle.guid)
      for _, suggestion in ipairs(accepted) do
        self.workflow:emit_event('suggestion_decided', {
          needle_id = needle.guid,
          suggestion_id = suggestion.guid,
          action = 'accepted',
          summary = summary,
          timestamp = os.time(),
        })
      end
    end

    -- Empty rolls line up for the diagnosis pass; a roll that found
    -- something outdates any verdict from an earlier session
    if #persisted == 0 then
      table.insert(self.diagnosis_queue, needle)
    else
      local diagnosis = self:get_diagnosis()
      if diagnosis then
        diagnosis:clear(needle.locator)
      end
    end
end

function OneshotRunner:tick_diagnosis(diagnosis)
  local needle = table.remove(self.diagnosis_queue, 1)
  if not needle then return end

  local ok, verdict = pcall(diagnosis.diagnose, diagnosis, needle)
  if not ok then
    self:log('Oneshot diagnosis failed for needle ' .. tostring(needle.guid) .. ': ' .. tostring(verdict))
    verdict = nil
  end

  self.diagnosed = self.diagnosed + 1

  self.workflow:emit_event('needle_diagnosed', {
    needle_id = needle.guid,
    locator = needle.locator,
    verdict = verdict,
  })
end

-- The dice end of the slider: accept fresh pending suggestions the
-- odds favor. Long shots never auto-accept - their whole point is a
-- human ear. Returns the accepted suggestion records.
function OneshotRunner:auto_accept(needle_guid, persisted)
  local threshold = self.auto_accept_threshold
  if not threshold then return {} end

  local state_manager = self.workflow:get_suggestion_state_manager()
  local accepted = {}

  for _, suggestion in ipairs(persisted) do
    if suggestion.state == 'pending'
      and not suggestion.long_shot
      and (suggestion.confidence or 0) >= threshold then
      local ok, updated = pcall(function()
        return state_manager:record_decision(needle_guid, suggestion.guid, 'accepted')
      end)
      if ok and updated then
        table.insert(accepted, updated)
      elseif not ok then
        self:log('Oneshot auto-accept failed for suggestion '
          .. tostring(suggestion.guid) .. ': ' .. tostring(updated))
      end
    end
  end

  self.auto_accepted = self.auto_accepted + #accepted
  return accepted
end

-- Acknowledge completion (the UI switches phases, then calls this)
function OneshotRunner:reset()
  self.state = 'idle'
  self.queue = {}
end
