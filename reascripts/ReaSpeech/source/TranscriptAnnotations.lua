--[[

  TranscriptAnnotations.lua - create/manage markers and regions for transcripts

]]--

TranscriptAnnotations = Polo {}

function TranscriptAnnotations:init()
  assert(self.transcript, "TranscriptAnnotations: transcript is required")

  Logging.init(self, 'TranscriptAnnotations')
end

function TranscriptAnnotations:take_markers(use_words, track_filter_config)
    track_filter_config = track_filter_config or { mode = 'ignore', tracks = {} }

    local oddly_specific_black = 0x01030405

    local takes = {}

    for element in self.transcript:iterator(use_words) do
      local _, take_guid = reaper.GetSetMediaItemTakeInfo_String(element.take, 'GUID', '', false)

      if not takes[take_guid] then
        takes[take_guid] = {}
        local path = ReaUtil.get_source_path(element.take)

        for item in ReaIter.each_media_item() do
          for take in ReaIter.each_take(item) do
            local take_path = ReaUtil.get_source_path(take)

            if take_path == path then
              local track_guid = reaper.GetTrackGUID(reaper.GetMediaItemTake_Track(take))
              if track_filter_config.mode == 'ignore' and not track_filter_config.tracks[track_guid]
              or track_filter_config.mode == 'include' and track_filter_config.tracks[track_guid] then
                table.insert(takes[take_guid], take)
              end
            end
          end
        end
      end

      for _, take in ipairs(takes[take_guid]) do
        reaper.SetTakeMarker(take, -1, element.text, element.start, oddly_specific_black)
      end
    end
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

  for element in self.transcript:iterator(use_words) do
    local offset = Transcript.calculate_offset(element.item, element.take)
    local want_index = element.id or 0
    local color = 0

    local start = element.start + offset
    local end_ = element.end_ + offset
    reaper.AddProjectMarker2(project, use_regions, start, end_, element.text, want_index, color)
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
