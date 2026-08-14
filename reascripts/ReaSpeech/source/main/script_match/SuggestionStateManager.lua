--[[

  SuggestionStateManager.lua - Manages persistence of suggestion states and editorial decisions

  Single store: each needle has one suggestions file holding every
  suggestion with its `state` ('pending' | 'accepted' | 'rejected') and
  editorial log. Accepted/rejected views are derived by filtering, never
  persisted separately.

  Storage Architecture:
    sessions/<session_guid>/
    ├── suggestions.json                       # Index of needle suggestion collections
    └── suggestions/
        ├── <needle_guid_1>.json              # All suggestions for needle 1
        ├── <needle_guid_2>.json              # All suggestions for needle 2
        └── ...

  Records written before the store was consolidated may carry the old
  `current_state` field (and stale decided copies existed in separate
  accepted_suggestions/rejected_suggestions trees, now unused);
  normalize_state folds `current_state` into `state` on every load.

]]--

SuggestionStateManager = Polo {}

function SuggestionStateManager:init()
  Logging().init(self, 'SuggestionStateManager')

  assert(self.session_id, 'SuggestionStateManager: session_id is required')

  self.suggestions_index = self:get_suggestions_index_storage()
end

-- Storage System Initialization

function SuggestionStateManager:session_storage_location()
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function SuggestionStateManager:needle_suggestions_storage_location(needle_guid)
  assert(needle_guid, 'SuggestionStateManager:needle_suggestions_storage_location: needle_guid is required')
  return ('%s/suggestions/%s.json'):format(self:session_storage_location(), needle_guid)
end

function SuggestionStateManager:get_needle_suggestions_storage(needle_guid)
  assert(needle_guid, 'SuggestionStateManager:get_needle_suggestions_storage: needle_guid is required')

  local storage_location = self:needle_suggestions_storage_location(needle_guid)
  return Storage.ProjectJSON(storage_location, {
    schema_version = 1,
    migrations = {}
  }):table('suggestions', {})
end

function SuggestionStateManager:get_suggestions_index_storage()
  local json_file = self:session_storage_location() .. '/suggestions.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  }):table('needle_collections', {})
end

-- State Normalization

-- Fold the legacy `current_state` field into `state`. Mutates and
-- returns the record.
function SuggestionStateManager.normalize_state(suggestion)
  suggestion.state = suggestion.state or suggestion.current_state or 'pending'
  suggestion.current_state = nil
  return suggestion
end

-- Suggestion Persistence

-- Standardize raw matcher output (guid/id, timestamps, pending state)
-- and persist it as the needle's fresh generation. Shared by the
-- curation card and the oneshot batch so both persist identically.
function SuggestionStateManager:persist_generated(needle_guid, raw_suggestions)
  local processed = {}

  for _, raw in ipairs(raw_suggestions or {}) do
    local suggestion = {}
    for k, v in pairs(raw) do
      suggestion[k] = v
    end

    suggestion.guid = suggestion.guid or reaper.genGuid('')
    suggestion.id = suggestion.guid
    suggestion.created_at = os.time()
    suggestion.needle_id = needle_guid
    suggestion.state = suggestion.state or 'pending'

    table.insert(processed, suggestion)
  end

  return self:replace_pending_suggestions(needle_guid, processed)
end

-- Replace a needle's pending suggestions with a fresh generation, keeping
-- decided (accepted/rejected) ones and dropping incoming duplicates of
-- their spans. Returns the merged list as persisted.
function SuggestionStateManager:replace_pending_suggestions(needle_guid, new_suggestions)
  assert(needle_guid, 'SuggestionStateManager:replace_pending_suggestions: needle_guid is required')
  assert(new_suggestions, 'SuggestionStateManager:replace_pending_suggestions: new_suggestions is required')

  local merged = SuggestionStateManager.merge_replacing_pending(
    self:load_needle_suggestions(needle_guid),
    self:_prepare_new_suggestions(needle_guid, new_suggestions))

  self:save_needle_suggestions(needle_guid, merged)

  self:log(string.format("Replaced pending suggestions for needle %s (total: %d)",
    needle_guid, #merged))

  return merged
end

-- Pure merge: keep decided suggestions, drop previously pending ones, and
-- filter incoming suggestions that duplicate a decided suggestion's span.
-- A decided suggestion is backfilled with fields it is missing from its
-- incoming duplicate (same span = same match), so decisions made before
-- a field existed (e.g. the source file) heal on regeneration.
function SuggestionStateManager.merge_replacing_pending(existing, incoming)
  local merged = {}
  local decided_spans = {}

  for _, suggestion in ipairs(existing) do
    if suggestion.state and suggestion.state ~= 'pending' then
      table.insert(merged, suggestion)
      decided_spans[SuggestionStateManager.span_key(suggestion)] = suggestion
    end
  end

  for _, suggestion in ipairs(incoming) do
    local decided = decided_spans[SuggestionStateManager.span_key(suggestion)]
    if decided then
      for key, value in pairs(suggestion) do
        if decided[key] == nil then
          decided[key] = value
        end
      end
    else
      table.insert(merged, suggestion)
    end
  end

  return merged
end

-- Identity of the matched audio span, independent of suggestion GUIDs,
-- which differ between generations.
function SuggestionStateManager.span_key(suggestion)
  local track_guid = suggestion.track_guids and suggestion.track_guids[1] or ''
  return ('%s|%s|%s'):format(track_guid,
    tostring(suggestion.start_time), tostring(suggestion.end_time))
end

-- Add editorial logging metadata and derived state to each new suggestion
function SuggestionStateManager:_prepare_new_suggestions(needle_guid, new_suggestions)
  local prepared = {}
  for _, suggestion in ipairs(new_suggestions) do
    local suggestion_copy = {}

    for k, v in pairs(suggestion) do
      suggestion_copy[k] = v
    end

    if not suggestion_copy.editorial_log then
      suggestion_copy.editorial_log = {
        {
          action = 'generated',
          timestamp = os.time(),
          metadata = {
            session_id = self.session_id,
            needle_id = needle_guid,
          }
        }
      }
    end

    SuggestionStateManager.normalize_state(suggestion_copy)

    if not suggestion_copy.last_modified then
      suggestion_copy.last_modified = os.time()
    end

    table.insert(prepared, suggestion_copy)
  end

  return prepared
end

function SuggestionStateManager:save_needle_suggestions(needle_guid, suggestions)
  assert(needle_guid, 'SuggestionStateManager:save_needle_suggestions: needle_guid is required')
  assert(suggestions, 'SuggestionStateManager:save_needle_suggestions: suggestions is required')

  local storage = self:get_needle_suggestions_storage(needle_guid)
  storage:set(suggestions)

  self:update_suggestions_index(needle_guid, #suggestions)

  self:log(string.format("Saved %d suggestions for needle %s", #suggestions, needle_guid))
end

function SuggestionStateManager:load_needle_suggestions(needle_guid)
  assert(needle_guid, 'SuggestionStateManager:load_needle_suggestions: needle_guid is required')

  local suggestions = self:get_needle_suggestions_storage(needle_guid):get()

  for _, suggestion in ipairs(suggestions) do
    SuggestionStateManager.normalize_state(suggestion)
  end

  return suggestions
end

-- Derived view: accepted suggestions for one needle
function SuggestionStateManager:load_accepted_suggestions(needle_guid)
  local accepted = {}
  for _, suggestion in ipairs(self:load_needle_suggestions(needle_guid)) do
    if suggestion.state == 'accepted' then
      table.insert(accepted, suggestion)
    end
  end
  return accepted
end

-- Editorial Decisions

-- Record an accept/reject decision on one suggestion: updates its state,
-- appends to its editorial log, and persists the needle's list in a
-- single write. Returns the updated record, or nil if the guid is not
-- found in the needle's suggestions.
-- Persist an edited time window (keyboard nudge/resize). Marks the
-- suggestion time_adjusted - its window no longer equals the matcher
-- output. Returns the updated suggestion, or nil when not found.
function SuggestionStateManager:adjust_suggestion_times(needle_guid, suggestion_guid, start_time, end_time)
  assert(needle_guid, 'SuggestionStateManager:adjust_suggestion_times: needle_guid is required')
  assert(suggestion_guid, 'SuggestionStateManager:adjust_suggestion_times: suggestion_guid is required')
  assert(start_time and end_time and end_time > start_time,
    'SuggestionStateManager:adjust_suggestion_times: invalid time range')

  local suggestions = self:load_needle_suggestions(needle_guid)

  for _, suggestion in ipairs(suggestions) do
    if suggestion.guid == suggestion_guid then
      suggestion.start_time = start_time
      suggestion.end_time = end_time
      suggestion.time_adjusted = true
      suggestion.last_modified = os.time()

      self:save_needle_suggestions(needle_guid, suggestions)

      return suggestion
    end
  end

  return nil
end

function SuggestionStateManager:record_decision(needle_guid, suggestion_guid, action)
  assert(needle_guid, 'SuggestionStateManager:record_decision: needle_guid is required')
  assert(suggestion_guid, 'SuggestionStateManager:record_decision: suggestion_guid is required')
  assert(action == 'accepted' or action == 'rejected' or action == 'pending',
    'SuggestionStateManager:record_decision: invalid action: ' .. tostring(action))

  local suggestions = self:load_needle_suggestions(needle_guid)

  for _, suggestion in ipairs(suggestions) do
    if suggestion.guid == suggestion_guid then
      suggestion.state = action
      suggestion.editorial_log = suggestion.editorial_log or {}
      table.insert(suggestion.editorial_log, {
        action = action,
        timestamp = os.time()
      })
      suggestion.last_modified = os.time()

      self:save_needle_suggestions(needle_guid, suggestions)

      self:log(string.format("Recorded decision '%s' for suggestion %s (needle %s)",
        action, suggestion_guid, needle_guid))

      return suggestion
    end
  end

  self:log(string.format("WARNING: record_decision found no suggestion %s for needle %s",
    suggestion_guid, needle_guid))
end

-- Index Management

function SuggestionStateManager:update_suggestions_index(needle_guid, count)
  assert(needle_guid, 'SuggestionStateManager:update_suggestions_index: needle_guid is required')

  local index = self.suggestions_index:get()

  local entry = nil
  for _, existing_entry in ipairs(index) do
    if existing_entry.needle_guid == needle_guid then
      entry = existing_entry
      break
    end
  end

  if not entry then
    entry = {
      needle_guid = needle_guid,
      created_at = os.time()
    }
    table.insert(index, entry)
  end

  entry.last_modified = os.time()
  entry.count = count or #self:load_needle_suggestions(needle_guid)

  self.suggestions_index:set(index)
end

function SuggestionStateManager:get_needles_with_suggestions()
  return self.suggestions_index:get()
end

-- Utility Methods

function SuggestionStateManager:get_suggestion_summary(needle_guid)
  assert(needle_guid, 'SuggestionStateManager:get_suggestion_summary: needle_guid is required')

  local suggestions = self:load_needle_suggestions(needle_guid)

  local summary = {
    total = #suggestions,
    accepted = 0,
    rejected = 0,
    pending = 0
  }

  for _, suggestion in ipairs(suggestions) do
    if suggestion.state == 'accepted' then
      summary.accepted = summary.accepted + 1
    elseif suggestion.state == 'rejected' then
      summary.rejected = summary.rejected + 1
    else
      summary.pending = summary.pending + 1
    end
  end

  return summary
end

return SuggestionStateManager
