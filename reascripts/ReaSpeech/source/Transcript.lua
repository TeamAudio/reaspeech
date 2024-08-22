--[[

  Transcript.lua - Speech transcription data model

]]--

Transcript = Polo {
  COLUMN_ORDER = {"id", "seek", "start", "end", "text", "score", "file"},
  DEFAULT_HIDE = {
    seek = true, temperature = true, tokens = true, avg_logprob = true,
    compression_ratio = true, no_speech_prob = true
  },

  init = function(self)
    self:clear()
  end
}

Transcript.calculate_offset = function (item, take)
  return (
    reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    - reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS'))
end

function Transcript:clear()
  self.init_data = {}
  self.filtered_data = {}
  self.data = {}
  self.search = ''
end

function Transcript:get_columns()
  if #self.init_data > 0 then
    local columns = {"score"}
    local row = self.init_data[1]
    for k, _ in pairs(row.data) do
      if k:sub(1, 1) ~= '_' then
        table.insert(columns, k)
      end
    end
    return self:_sort_columns(columns)
  end
  return {}
end

function Transcript:_sort_columns(columns)
  local order = self.COLUMN_ORDER

  local column_set = {}
  local extra_columns = {}
  local order_set = {}
  local result = {}

  for _, column in pairs(columns) do
    column_set[column] = true
  end

  for _, column in pairs(order) do
    order_set[column] = true
    if column_set[column] then
      table.insert(result, column)
    end
  end

  for _, column in pairs(columns) do
    if not order_set[column] then
      table.insert(extra_columns, column)
    end
  end

  table.sort(extra_columns)
  for _, column in pairs(extra_columns) do
    table.insert(result, column)
  end

  return result
end

function Transcript:add_segment(segment)
  table.insert(self.init_data, segment)
end

function Transcript:has_segments()
  return #self.init_data > 0
end

function Transcript:get_segments()
  return self.data
end

function Transcript:sort(column, ascending)
  self.data = {table.unpack(self.filtered_data)}
  table.sort(self.data, function (a, b)
    local a_val, b_val = a:get(column), b:get(column)
    if a_val == nil then a_val = '' end
    if b_val == nil then b_val = '' end
    if type(a_val) == 'table' then a_val = table.concat(a_val, ', ') end
    if type(b_val) == 'table' then b_val = table.concat(b_val, ', ') end
    if not ascending then
      a_val, b_val = b_val, a_val
    end
    return a_val < b_val
  end)
end

function Transcript:to_table()
  local segments = {}
  for _, segment in pairs(self.data) do
    table.insert(segments, segment:to_table())
  end
  return {segments = segments}
end

function Transcript:to_json()
  return json.encode(self:to_table())
end

function Transcript:update()
  if #self.init_data == 0 then
    self:clear()
    return
  end

  local columns = self:get_columns()

  if #self.search > 0 then
    local search = self.search
    local search_lower = search:lower()
    local match_case = (search ~= search_lower)
    self.filtered_data = {}

    for _, segment in pairs(self.init_data) do
      local matching = false
      for _, column in pairs(columns) do
        if match_case then
          if tostring(segment.data[column]):find(search) then
            matching = true
            break
          end
        else
          if tostring(segment.data[column]):lower():find(search_lower) then
            matching = true
            break
          end
        end
      end
      if matching then
        table.insert(self.filtered_data, segment)
      end
    end
  else
    self.filtered_data = self.init_data
  end

  self.data = self.filtered_data
end

function Transcript:create_markers(proj, regions, words)
  proj = proj or 0
  regions = regions or false
  for i, segment in pairs(self.data) do
    local offset = self.calculate_offset(segment.item, segment.take)
    local want_index = segment:get('id', i)
    local color = 0
    if words then
      for _, word in pairs(segment.words) do
        local start = word.start + offset
        local end_ = word.end_ + offset
        local name = word.word
        reaper.AddProjectMarker2(proj, regions, start, end_, name, want_index, color)
      end
    else
      local start = segment.start + offset
      local end_ = segment.end_ + offset
      local name = segment.text
      reaper.AddProjectMarker2(proj, regions, start, end_, name, want_index, color)
    end
  end
end

function Transcript:create_notes_track(words)
  local cur_pos = reaper.GetCursorPosition()
  local index = 0
  reaper.InsertTrackAtIndex(index, false)
  local track = reaper.GetTrack(0, index)
  reaper.SetOnlyTrackSelected(track)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', 'Speech', true)
  for _, segment in pairs(self.data) do
    local offset = self.calculate_offset(segment.item, segment.take)
    if words then
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
  reaper.SetEditCurPos(cur_pos, true, true)
end

function Transcript:_create_note(start, end_, text, stretch)
  local item = self:_create_empty_item(start, end_)
  self:_set_note_text(item, text, stretch)
end

function Transcript:_create_empty_item(start, end_)
  self:_insert_empty_item()
  local item = reaper.GetSelectedMediaItem(0, 0)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemPosition(item, start, true)
  reaper.SetMediaItemLength(item, end_ - start, true)
  return item
end

function Transcript:_insert_empty_item()
  reaper.Main_OnCommand(40142, 0)
end

function Transcript:_set_note_text(item, text, stretch)
  local _, chunk = reaper.GetItemStateChunk(item, "", false)
  local notes_chunk = ("<NOTES\n|%s\n>\n"):format(text:match("^%s*(.-)%s*$"))
  local flags_chunk = (stretch and "IMGRESOURCEFLAGS 11\n" or "")
  chunk = chunk:gsub('>', notes_chunk:gsub('%%', '%%%%') .. flags_chunk .. '>')
  reaper.SetItemStateChunk(item, chunk, false)
end
