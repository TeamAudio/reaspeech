--[[

  TranscriptAnnotations.lua - create/manage markers and regions for transcripts

]]--

TranscriptAnnotations = Polo {
  DEFAULT_TAB = 'markers',

  -- new = function(transcript)
  --   return {
  --     transcript = transcript
  --   }
  -- end
}

function TranscriptAnnotations:init()
  assert(self.transcript, "TranscriptMarkers: transcript is required")

  Logging.init(self, 'TranscriptMarkers')
end

function TranscriptAnnotations:project_markers(project, use_words)
  project = project or 0

  self:create_project_markers(project, false, use_words)
end

function TranscriptAnnotations:project_regions(project, use_words)
  project = project or 0

  self:create_project_markers(project, true, use_words)
end

function TranscriptAnnotations:take_markers(use_words)
  for _, segment in pairs(self.transcript.data) do
    local oddly_specific_black = 0x01030405

    if use_words then
      for _, word in pairs(segment.words) do
        reaper.SetTakeMarker(segment.take, -1, word.word, word.start, oddly_specific_black)
      end
    else
      reaper.SetTakeMarker(segment.take, -1, segment.text, segment.start, oddly_specific_black)
    end
  end
end

function TranscriptAnnotations:notes_track(use_words)
  self:create_notes_track(use_words)
end

function TranscriptAnnotations:create_project_markers(project, use_regions, use_words)
  project = project or 0
  use_regions = use_regions or false

  for i, segment in pairs(self.transcript.data) do
    self:debug('segment', segment)
    local offset = Transcript.calculate_offset(segment.item, segment.take)
    local want_index = segment:get('id', i)
    local color = 0

    if use_words then
      for _, word in pairs(segment.words) do
        local start = word.start + offset
        local end_ = word.end_ + offset
        local name = word.word
        reaper.AddProjectMarker2(project, use_regions, start, end_, name, want_index, color)
      end
    else
      local start = segment.start + offset
      local end_ = segment.end_ + offset
      local name = segment.text
      reaper.AddProjectMarker2(project, use_regions, start, end_, name, want_index, color)
    end
  end
end

function TranscriptAnnotations:create_notes_track(use_words)
  local original_position = reaper.GetCursorPosition()
  local index = 0

  reaper.InsertTrackAtIndex(index, false)
  local track = reaper.GetTrack(0, index)
  reaper.SetOnlyTrackSelected(track)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', 'Speech', true)
  for _, segment in pairs(self.transcript.data) do
    local offset = Transcript.calculate_offset(segment.item, segment.take)

    if use_words then
      for _, word in pairs(segment.words) do
        local start = word.start + offset
        local end_ = word.end_ + offset
        local text = word.word
        self:_create_note(start, end_, text, false)
      end
    else
      local start = segment.start + offset
      local end_ = segment.end_ + offset
      local text = segment.text
      self:_create_note(start, end_, text, true)
    end
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
