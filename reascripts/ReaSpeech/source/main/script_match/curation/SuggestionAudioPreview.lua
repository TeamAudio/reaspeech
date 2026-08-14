--[[

  SuggestionAudioPreview.lua - play a suggestion's audio range in REAPER

  Suggestion times are relative to the source media file they were
  transcribed from, so playback first locates the media item on the
  suggestion's track whose active take uses that source file, then maps
  the file-relative range onto the project timeline.

  While a preview plays, the target track is soloed and playback is
  watched from the workflow's nudgeable pump. When the play cursor
  passes the end of the range - or the user stops the transport - solo
  states and the edit cursor are restored.

]]--

SuggestionAudioPreview = Polo {
  POLL_INTERVAL = 0.1,
  END_PADDING = 0.05,
}

function SuggestionAudioPreview:init()
  Logging().init(self, 'SuggestionAudioPreview')

  assert(self.workflow, 'SuggestionAudioPreview: workflow is required')
end

function SuggestionAudioPreview:is_active(suggestion)
  return self._active ~= nil and self._active == suggestion
end

-- Begin previewing a suggestion, stopping any current preview first.
-- Returns false when the suggestion cannot be located in the project.
function SuggestionAudioPreview:play(suggestion)
  self:stop()

  local range = SuggestionTimeline.resolve(suggestion)
  if not range then
    self:log('No media found for suggestion; cannot preview')
    return false
  end

  self._saved = self:_save_transport_state()
  self:_solo_track(range.track)

  reaper.SetEditCurPos(range.start_time, true, false)
  reaper.Main_OnCommand(ReaperConstants.TRANSPORT_PLAY, 0)

  self._active = suggestion
  self._range = range
  self:_watch_playback()

  return true
end

-- Where the play cursor sits within the active preview's range, 0..1
-- (clamped), or nil when this suggestion isn't previewing. Playrate is
-- already baked into the resolved range, so the fraction maps straight
-- onto the suggestion's source-relative window.
function SuggestionAudioPreview:playhead_fraction(suggestion)
  if not self._active or self._active ~= suggestion then return nil end

  local range = self._range
  local span = range.end_time - range.start_time
  if span <= 0 then return nil end

  local fraction = (reaper.GetPlayPosition() - range.start_time) / span
  if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
  return fraction
end

function SuggestionAudioPreview:stop()
  if not self._active then return end

  if reaper.GetPlayState() & 1 == 1 then
    reaper.Main_OnCommand(ReaperConstants.TRANSPORT_STOP, 0)
  end

  self:_restore_transport_state()
  self._active = nil
  self._range = nil
end

-- Watch the transport so the preview ends after the range plays out,
-- and state is restored even when the user stops playback themselves.
function SuggestionAudioPreview:_watch_playback()
  local interval = IntervalFunction().new(self.POLL_INTERVAL, function()
    if not self._active then return end

    if reaper.GetPlayState() & 1 == 0 then
      self:stop()
    elseif reaper.GetPlayPosition() >= self._range.end_time + self.END_PADDING then
      self:stop()
    end
  end)

  self.workflow:register_nudgeable(interval, function()
    return self._active == nil
  end)
end

function SuggestionAudioPreview:_save_transport_state()
  local solo_states = {}
  for _, pair in ipairs(ReaUtil.track_guids()) do
    local track = pair[2]
    table.insert(solo_states, { track, reaper.GetMediaTrackInfo_Value(track, 'I_SOLO') })
  end

  return {
    cursor = reaper.GetCursorPosition(),
    solo_states = solo_states,
  }
end

function SuggestionAudioPreview:_solo_track(target)
  for _, pair in ipairs(ReaUtil.track_guids()) do
    local track = pair[2]
    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', track == target and 1 or 0)
  end
end

function SuggestionAudioPreview:_restore_transport_state()
  local saved = self._saved
  if not saved then return end

  for _, entry in ipairs(saved.solo_states) do
    -- Tracks can disappear mid-preview; restore the ones that remain
    Trap(function()
      reaper.SetMediaTrackInfo_Value(entry[1], 'I_SOLO', entry[2])
    end)
  end

  reaper.SetEditCurPos(saved.cursor, false, false)
  self._saved = nil
end
