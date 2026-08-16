--[[

  ClaimedSpans.lua - the timeline territory accepted takes own

  Every accepted suggestion is a human-confirmed claim: "this stretch
  of this track is line N." The matcher consults these to keep other
  needles off claimed territory (span exclusion) and gap inference
  reads them to narrow where a straggler must live. Event-invalidated
  and recomputed lazily, same pattern as SessionStatus.

]]--

ClaimedSpans = Polo {}

ClaimedSpans.INVALIDATING_EVENTS = {
  'suggestion_decided',
  'suggestions_generated',
  'suggestion_time_adjusted',
}

function ClaimedSpans:init()
  Logging().init(self, 'ClaimedSpans')

  assert(self.workflow, 'ClaimedSpans: workflow is required')

  self._dirty = true

  for _, event_name in ipairs(ClaimedSpans.INVALIDATING_EVENTS) do
    self.workflow:listen_for_event(event_name, function()
      self._dirty = true
    end)
  end
end

-- Per-track claims: { [track_guid] = { {start_time, end_time,
-- needle_guid}, ... } }. The matcher's exclusion input.
function ClaimedSpans:by_track()
  self:_recompute_if_dirty()
  return self._by_track
end

-- Accepted spans per needle: { [needle_guid] = { {track_guid,
-- start_time, end_time}, ... } }. Gap inference's input.
function ClaimedSpans:by_needle()
  self:_recompute_if_dirty()
  return self._by_needle
end

function ClaimedSpans:_recompute_if_dirty()
  if not self._dirty then return end

  local state_manager = self.workflow:get_suggestion_state_manager()
  self._by_track = {}
  self._by_needle = {}

  for _, entry in ipairs(state_manager:get_needles_with_suggestions()) do
    local needle_guid = entry.needle_guid
    if needle_guid and (entry.count or 0) > 0 then
      for _, suggestion in ipairs(state_manager:load_accepted_suggestions(needle_guid)) do
        if suggestion.start_time and suggestion.end_time then
          for _, track_guid in ipairs(suggestion.track_guids or {}) do
            self._by_track[track_guid] = self._by_track[track_guid] or {}
            table.insert(self._by_track[track_guid], {
              start_time = suggestion.start_time,
              end_time = suggestion.end_time,
              needle_guid = needle_guid,
            })

            self._by_needle[needle_guid] = self._by_needle[needle_guid] or {}
            table.insert(self._by_needle[needle_guid], {
              track_guid = track_guid,
              start_time = suggestion.start_time,
              end_time = suggestion.end_time,
            })
          end
        end
      end
    end
  end

  self._dirty = false
end
