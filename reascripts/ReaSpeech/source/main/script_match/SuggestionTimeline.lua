--[[

  SuggestionTimeline.lua - map suggestion times onto the project timeline

  Suggestion (and export item) times are relative to the source media
  file they were transcribed from. Resolving locates the media item on
  the suggestion's track whose active take plays that source file, and
  converts the file-relative range to project timeline positions,
  honoring take start offsets and playrates.

  Stateless; shared by the curation audio preview and the export phase.

]]--

SuggestionTimeline = {}

-- Resolve a suggestion-shaped table (start_time, end_time, track_guids,
-- optional file) to { track, start_time, end_time } on the timeline,
-- or nil when it cannot be located in the project.
function SuggestionTimeline.resolve(suggestion)
  if not suggestion.start_time or not suggestion.end_time then return nil end

  local track_guid = suggestion.track_guids and suggestion.track_guids[1]
  if not track_guid then return nil end

  local track = SuggestionTimeline.track_by_guid(track_guid)
  if not track then return nil end

  local item, take = SuggestionTimeline.find_media(track, suggestion)
  if not item then return nil end

  local item_position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  local start_offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
  if playrate == 0 then playrate = 1 end

  return {
    track = track,
    start_time = item_position + (suggestion.start_time - start_offset) / playrate,
    end_time = item_position + (suggestion.end_time - start_offset) / playrate,
    item_start = item_position,
    item_end = item_position + item_length,
    source_path = ReaUtil.get_source_path(take),
    -- Gain context, so re-created media can audition at source loudness
    item_volume = reaper.GetMediaItemInfo_Value(item, 'D_VOL'),
    take_volume = reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL'),
  }
end

function SuggestionTimeline.track_by_guid(guid)
  for _, pair in ipairs(ReaUtil.track_guids()) do
    if pair[1] == guid then
      return pair[2]
    end
  end
end

-- Find the media item on the track whose active take plays the
-- suggestion's source file at the suggestion's time. Falls back to the
-- first item using the right file, so a trimmed take still resolves
-- approximately rather than not at all.
function SuggestionTimeline.find_media(track, suggestion)
  local wanted_file = suggestion.file

  local fallback_item, fallback_take

  for item in ReaIter.each_track_item(track) do
    local take = reaper.GetActiveTake(item)
    if take then
      local source_path = ReaUtil.get_source_path(take)
      local source_file = source_path
        and PathUtil.get_filename(source_path):gsub('(.*)[.].*', '%1')

      if not wanted_file or wanted_file == '' or source_file == wanted_file then
        local start_offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
        local playrate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
        if playrate == 0 then playrate = 1 end
        local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        local source_end = start_offset + length * playrate

        if suggestion.start_time >= start_offset and suggestion.start_time < source_end then
          return item, take
        end

        if not fallback_item then
          fallback_item, fallback_take = item, take
        end
      end
    end
  end

  return fallback_item, fallback_take
end
