--[[

  TranscriptAnnotations.lua - create/manage markers and regions for transcripts

]]--

TranscriptAnnotations = Polo {}

function TranscriptAnnotations:init()
  assert(self.transcript, "TranscriptAnnotations: transcript is required")

  Logging().init(self, 'TranscriptAnnotations')
end

function TranscriptAnnotations:take_markers(use_words, track_filter_config)
  track_filter_config = track_filter_config or { mode = 'ignore', tracks = {} }

  local oddly_specific_black = 0x01030405

  local source_paths = {}
  local targets_by_path = {}
  local stamped = {}

  for element in self.transcript:iterator(use_words) do
    local path = source_paths[element.take]

    if path == nil then
      -- a transcript reloaded in a changed project can hold takes that no
      -- longer exist; skip their elements instead of erroring out
      local ok, result = Trap(function ()
        return ReaUtil.get_source_path(element.take)
      end)
      path = ok and result or false
      source_paths[element.take] = path
    end

    if path and element.text then
      if not targets_by_path[path] then
        targets_by_path[path] = self:_take_marker_targets(path, track_filter_config)
      end

      for _, target in ipairs(targets_by_path[path]) do
        if not target.window_start
        or (element.start >= target.window_start and element.start < target.window_end) then
          if not stamped[target.take] then
            stamped[target.take] = self._existing_take_markers(target.take)
          end

          local marker_key = element.start .. '\0' .. element.text
          if not stamped[target.take][marker_key] then
            stamped[target.take][marker_key] = true
            reaper.SetTakeMarker(target.take, -1, element.text, element.start, oddly_specific_black)
          end
        end
      end
    end
  end
end

function TranscriptAnnotations:_take_marker_targets(path, track_filter_config)
  local targets = {}

  for item in ReaIter.each_media_item() do
    for take in ReaIter.each_take(item) do
      if ReaUtil.get_source_path(take) == path
      and self._track_filter_allows(track_filter_config, take) then
        local window_start, window_end = TranscriptSegment.take_source_window(item, take)

        table.insert(targets, {
          take = take,
          window_start = window_start,
          window_end = window_end
        })
      end
    end
  end

  return targets
end

function TranscriptAnnotations._track_filter_allows(track_filter_config, take)
  local track_guid = reaper.GetTrackGUID(reaper.GetMediaItemTake_Track(take))

  if track_filter_config.mode == 'ignore' then
    return not track_filter_config.tracks[track_guid]
  elseif track_filter_config.mode == 'include' then
    return track_filter_config.tracks[track_guid] and true or false
  end

  return false
end

function TranscriptAnnotations._existing_take_markers(take)
  local existing = {}

  for i = 0, reaper.GetNumTakeMarkers(take) - 1 do
    local position, name = reaper.GetTakeMarker(take, i)
    existing[position .. '\0' .. name] = true
  end

  return existing
end

function TranscriptAnnotations:project_markers(project, use_words)
  self:create_project_markers(project, false, use_words)
end

function TranscriptAnnotations:project_regions(project, use_words)
  self:create_project_markers(project, true, use_words)
end

function TranscriptAnnotations:create_project_markers(project, use_regions, use_words)
  project = project or 0
  use_regions = use_regions or false
  use_words = use_words or false

  local marker_index = 1
  for element in self.transcript:iterator(use_words) do
    local offset = Transcript.calculate_offset(element.item, element.take)
    local want_index = element.id or marker_index
    local color = 0

    local start = element.start + offset
    local end_ = element.end_ + offset
    reaper.AddProjectMarker2(project, use_regions, start, end_, element.text, want_index, color)
    marker_index = marker_index + 1
  end
end

function TranscriptAnnotations:notes_track(use_words, track_name)
  track_name = track_name or 'Speech'
  local stretch = not use_words
  local original_position = reaper.GetCursorPosition()

  local index = 0
  reaper.InsertTrackAtIndex(index, false)
  local track = reaper.GetTrack(0, index)
  reaper.SetOnlyTrackSelected(track)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)

  for element in self.transcript:iterator(use_words) do
    local offset = Transcript.calculate_offset(element.item, element.take)
    local start = element.start + offset
    local end_ = element.end_ + offset
    self:_create_note(start, end_, element.text, stretch)
  end

  reaper.SetEditCurPos(original_position, true, true)
end

function TranscriptAnnotations:_create_note(start, end_, text, stretch)
  local item = self:_create_empty_item(start, end_)
  self:_set_note_text(item, text, stretch)
end

function TranscriptAnnotations:_create_empty_item(start, end_)
  self:_insert_empty_item()
  local item = reaper.GetSelectedMediaItem(0, 0)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemPosition(item, start, true)
  reaper.SetMediaItemLength(item, end_ - start, true)
  return item
end

function TranscriptAnnotations:_insert_empty_item()
  reaper.Main_OnCommand(40142, 0)
end

function TranscriptAnnotations:_set_note_text(item, text, stretch)
  local _, chunk = reaper.GetItemStateChunk(item, "", false)
  local notes_chunk = ("<NOTES\n|%s\n>\n"):format(text:match("^%s*(.-)%s*$"))
  local flags_chunk = (stretch and "IMGRESOURCEFLAGS 11\n" or "")
  chunk = chunk:gsub('>', notes_chunk:gsub('%%', '%%%%') .. flags_chunk .. '>')
  reaper.SetItemStateChunk(item, chunk, false)
end
