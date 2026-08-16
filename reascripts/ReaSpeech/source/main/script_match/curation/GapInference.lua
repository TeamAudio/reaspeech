--[[

  GapInference.lua - script order narrows where a straggler lives

  If line 11's accepted take ends at T1 and line 13's starts at T2 on
  the same track, unmatched line 12 most plausibly lives in (T1, T2):
  the timeline itself is evidence. Pure function over the
  script-ordered needle list and the accepted spans by needle.

]]--

GapInference = {}

-- Returns { track_guid, start_time, end_time } when the nearest
-- claim-bearing neighbors before and after the target share a track
-- and leave a positive window between them; nil otherwise. When
-- several tracks qualify, the tightest window wins (strongest
-- evidence).
function GapInference.window_for(needles, index, spans_by_needle)
  local function nearest_spans(from, to, step)
    for i = from, to, step do
      local needle = needles[i]
      local spans = needle and needle.guid and spans_by_needle[needle.guid]
      if spans and #spans > 0 then return spans end
    end
  end

  local prev_spans = nearest_spans(index - 1, 1, -1)
  local next_spans = nearest_spans(index + 1, #needles, 1)
  if not prev_spans or not next_spans then return nil end

  local best
  for _, prev in ipairs(prev_spans) do
    for _, following in ipairs(next_spans) do
      if prev.track_guid == following.track_guid
        and following.start_time > prev.end_time then
        local window = {
          track_guid = prev.track_guid,
          start_time = prev.end_time,
          end_time = following.start_time,
        }
        if not best
          or (window.end_time - window.start_time) < (best.end_time - best.start_time) then
          best = window
        end
      end
    end
  end

  return best
end
