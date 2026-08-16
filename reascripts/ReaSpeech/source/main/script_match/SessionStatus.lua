--[[

  SessionStatus.lua - Derived completion counts for a Script Matching session

  One event-invalidated summary over the single-owner stores, cheap
  enough for phase headers to read every frame:

    tracks              linked audio tracks
    materials           linked script materials
    lines               needles in the last generated list (0 until
                        needles have been generated this session)
    with_suggestions    needles that have generated suggestions
    curated             needles resolved: something accepted, or every
                        suggestion explicitly rejected
    accepted            accepted suggestions (the export workload)
    exported            export items marked completed

  Curation counts come from the suggestion store on disk, so they are
  correct after reopening a session even before needles regenerate.

]]--

SessionStatus = Polo {}

SessionStatus.INVALIDATING_EVENTS = {
  'needles_changed',
  'suggestions_generated',
  'suggestion_decided',
  'script_material_updated',
  'script_material_unlinked',
  'export_status_changed',
  'needle_diagnosed',
}

function SessionStatus:init()
  Logging().init(self, 'SessionStatus')

  assert(self.session_id, 'SessionStatus: session_id is required')
  assert(self.workflow, 'SessionStatus: workflow is required')

  self._dirty = true
  self._summary = nil
  self._needles = {}

  for _, event_name in ipairs(SessionStatus.INVALIDATING_EVENTS) do
    self.workflow:listen_for_event(event_name, function()
      self._dirty = true
    end)
  end

  self.workflow:listen_for_event('needles_changed', function(event)
    self._needles = event.needles or {}
  end)
end

function SessionStatus:summary()
  if self._dirty then
    self._summary = self:compute_summary()
    self._dirty = false
  end

  return self._summary
end

-- Per-needle suggestion summary ({total, accepted, rejected, pending}),
-- or nil for needles with no generated suggestions. Same freshness as
-- summary().
function SessionStatus:needle_summary(needle_guid)
  self:summary()
  return self._needle_summaries[needle_guid]
end

-- A needle is curated once something is accepted, or every suggestion
-- has been explicitly rejected. A needle whose generation found
-- NOTHING is not curated - nothing was ever judged (it used to count
-- via the vacuous pending == 0, wearing a green check it hadn't earned)
function SessionStatus.is_curated(needle_summary)
  return needle_summary.accepted > 0
    or (needle_summary.total > 0 and needle_summary.pending == 0)
end

function SessionStatus:compute_summary()
  local live_guids, line_count, live_locators = self:live_needle_guids()

  local summary = {
    tracks = #self.workflow:audio_tracks(),
    materials = #self.workflow:script_materials(),
    lines = line_count,
    with_suggestions = 0,
    curated = 0,
    accepted = 0,
    excluded = 0,
    exported = self:count_exported(),
  }

  local state_manager = self.workflow:get_suggestion_state_manager()

  self._needle_summaries = {}

  for _, entry in ipairs(state_manager:get_needles_with_suggestions()) do
    if live_guids[entry.needle_guid] then
      local needle_summary = state_manager:get_suggestion_summary(entry.needle_guid)

      -- Zero-total summaries stay visible to per-needle consumers (the
      -- nav flags rolled-but-empty lines red) but stay out of the
      -- session totals: nothing was found, let alone judged
      self._needle_summaries[entry.needle_guid] = needle_summary

      if needle_summary.total > 0 then
        summary.with_suggestions = summary.with_suggestions + 1
        summary.accepted = summary.accepted + needle_summary.accepted

        if SessionStatus.is_curated(needle_summary) then
          summary.curated = summary.curated + 1
        end
      end
    end
  end

  -- The excluded lane: lines diagnosed as never recorded leave the
  -- completion pressure but stay VISIBLE (silent denominator
  -- shrinkage would be the tool grading its own homework)
  local diagnoses = self:read_diagnoses()
  for guid in pairs(live_guids) do
    local verdict = live_locators[guid] and diagnoses[live_locators[guid]]
    if verdict and verdict.class == 'not_recorded' then
      local needle_summary = self._needle_summaries[guid]
      if not needle_summary or needle_summary.total == 0 then
        summary.excluded = summary.excluded + 1
      end
    end
  end

  return summary
end

function SessionStatus:read_diagnoses()
  return Storage.ProjectJSON(
    ('reaspeech/script_match/sessions/%s/diagnoses.json'):format(self.session_id),
    { schema_version = 1, migrations = {} }
  ):table('diagnoses', {}):get()
end

-- Needle guids belonging to currently linked materials, plus the
-- guid -> locator map (diagnoses key by locator). Persisted needle
-- stores and suggestion files survive unlinking, so every count must
-- be scoped to this set or it includes ghosts of unlinked materials.
function SessionStatus:live_needle_guids()
  local guids = {}
  local locators = {}
  local count = 0

  local function add(needles)
    for _, needle in ipairs(needles) do
      if needle.guid then
        guids[needle.guid] = true
        locators[needle.guid] = needle.locator
        count = count + 1
      end
    end
  end

  if #self._needles > 0 then
    add(self._needles)
    return guids, count, locators
  end

  -- Needles have not been generated this session; read the persisted
  -- stores for the linked materials
  for _, material in ipairs(self.workflow:script_materials()) do
    add(Storage.ProjectJSON(
      ('reaspeech/script_match/sessions/%s/needles/%s.json'):format(self.session_id, material.guid),
      { schema_version = 1, migrations = {} }
    ):table('needles', {}):get())
  end

  return guids, count, locators
end

function SessionStatus:count_exported()
  local statuses = Storage.ProjectJSON(
    ('reaspeech/script_match/sessions/%s/export_status.json'):format(self.session_id),
    { schema_version = 1, migrations = {} }
  ):table('file_statuses', {}):get()

  local exported = 0
  for _, status in pairs(statuses) do
    if status == 'completed' then
      exported = exported + 1
    end
  end

  return exported
end
