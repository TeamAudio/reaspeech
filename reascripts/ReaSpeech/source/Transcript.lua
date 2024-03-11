--[[

  Transcript.lua - Speech transcription data model

]]--

Transcript = {
  COLUMN_ORDER = {"id", "seek", "start", "end", "text", "score", "file"},
  DEFAULT_HIDE = {
    seek = true, temperature = true, tokens = true, avg_logprob = true,
    compression_ratio = true, no_speech_prob = true
  },
}

Transcript.__index = Transcript

Transcript.new = function (o)
  o = o or {}
  setmetatable(o, Transcript)
  o:init()
  return o
end

Transcript.calculate_offset = function (item, take)
  return (
    reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    - reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS'))
end

function Transcript:init()
  self:clear()
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
    if not ascending then
      a_val, b_val = b_val, a_val
    end
    return a_val < b_val
  end)
end

function Transcript:to_table()
  local segments = {}
  for _, segment in pairs(self.data) do
    local data = TranscriptSegment._copy(segment.data)
    if segment.words then
      data['words'] = {}
      for _, word in pairs(segment.words) do
        table.insert(data['words'], word:to_table())
      end
    end
    table.insert(segments, data)
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

TranscriptSegment = {
  _proxy_fields = {
    start = 'start',
    end_ = 'end',
    text = 'text',
  }
}

TranscriptSegment.__index = function(o, key)
  local proxy_target = TranscriptSegment._proxy_fields[key]
  if proxy_target then
    return o.data[proxy_target]
  else
    return TranscriptSegment[key]
  end
end

TranscriptSegment.new = function (o)
  o = o or {}
  setmetatable(o, TranscriptSegment)
  o:init()
  return o
end

TranscriptSegment.from_whisper = function(segment, item, take)
  local result = {}
  local words = segment.words

  segment = TranscriptSegment._copy(segment)
  segment.text = segment.text:match("^%s*(.-)%s*$")
  segment.words = nil

  if words then
    local transcript_words = {}
    for _, word in pairs(words) do
      local transcript_word = TranscriptWord.new({
        word = word.word:match("^%s*(.-)%s*$"),
        probability = word.probability,
        start = word.start,
        end_ = word['end']
      })
      table.insert(transcript_words, transcript_word)
    end
    table.insert(result, TranscriptSegment.new({
      data = segment,
      item = item,
      take = take,
      words = transcript_words
    }))
  else
    table.insert(result, TranscriptSegment.new({
      data = segment,
      item = item,
      take = take
    }))
  end

  return result
end

TranscriptSegment.default_hide = function(column)
  return Transcript.DEFAULT_HIDE[column] or false
end

TranscriptSegment.merge_words = function(words, index1, index2)
  local word1 = words[index1]
  local word2 = words[index2]
  local new_word = TranscriptWord.new {
    word = word1.word .. word2.word,
    start = word1.start,
    end_ = word2.end_,
    probability = (word1.probability + word2.probability) / 2
  }
  table.remove(words, index2)
  table.remove(words, index1)
  table.insert(words, index1, new_word)
end

TranscriptSegment.split_word = function(words, index)
  local word = words[index]
  local length = utf8.len(word.word)
  local half_length = math.floor(length / 2)
  local new_word1 = TranscriptWord.new {
    word = word.word:sub(1, utf8.offset(word.word, half_length)),
    start = word.start,
    end_ = word.start + (word.end_ - word.start) / 2,
    probability = word.probability
  }
  local new_word2 = TranscriptWord.new {
    word = word.word:sub(utf8.offset(word.word, half_length + 1)),
    start = word.start + (word.end_ - word.start) / 2,
    end_ = word.end_,
    probability = word.probability
  }
  table.remove(words, index)
  table.insert(words, index, new_word2)
  table.insert(words, index, new_word1)
end

TranscriptSegment._copy = function(data)
  local result = {}
  for k, v in pairs(data) do
    result[k] = v
  end
  return result
end

function TranscriptSegment:init()
  assert(self.data, 'missing data')
  assert(self.item, 'missing item')
  assert(self.take, 'missing take')
  self.data = self._copy(self.data)
  self.data['file'] = self:get_file()
end

function TranscriptSegment:score()
  local score = 0.0
  if self.words and #self.words > 0 then
    for _, word in pairs(self.words) do
      score = score + word:score()
    end
    return score / #self.words
  else
    return 0.0
  end
end

function TranscriptSegment:get(column, default)
  if column == 'score' then
    return self:score()
  elseif self.data[column] then
    return self.data[column]
  else
    return default
  end
end

function TranscriptSegment:set_words(words)
  self.words = words
  self:update_text()
end

function TranscriptSegment:update_text()
  local text_chunks = {}
  for _, word in pairs(self.words) do
    table.insert(text_chunks, word.word)
  end
  self.data['text'] = table.concat(text_chunks, ' ')
end

function TranscriptSegment:get_file()
  local file = ''
  app:trap(function ()
    local source = reaper.GetMediaItemTake_Source(self.take)
    if source then
      local source_path = reaper.GetMediaSourceFileName(source)
      file = source_path:gsub(".*[\\/](.*)", "%1"):gsub("(.*)[.].*", "%1")
    end
  end)
  return file
end

function TranscriptSegment:navigate(word_index, autoplay)
  local start = self.start
  if word_index then
    start = self.words[word_index].start
  end
  local offset = start - reaper.GetMediaItemTakeInfo_Value(self.take, 'D_STARTOFFS')
  self:_navigate_to_media_item(self.item)
  reaper.MoveEditCursor(offset, false)
  if autoplay and reaper.GetPlayState() & 1 == 0 then
    self:_transport_play()
  end
  if reaper.GetPlayState() & 1 == 1 then
    self:_transport_play()
  end
end

function TranscriptSegment:_navigate_to_media_item(item)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemSelected(item, true)
  self:_move_cursor_to_start_of_items()
end

function TranscriptSegment:_move_cursor_to_start_of_items()
  reaper.Main_OnCommand(41173, 0)
end

function TranscriptSegment:_transport_play()
  reaper.Main_OnCommand(1007, 0)
end

TranscriptWord = {}
TranscriptWord.__index = TranscriptWord

TranscriptWord.new = function (o)
  o = o or {}
  setmetatable(o, TranscriptWord)
  o:init()
  return o
end

function TranscriptWord:init()
  assert(self.word, 'missing word')
  assert(self.start, 'missing start')
  assert(self.end_, 'missing end_')
  assert(self.probability, 'missing probability')
end

function TranscriptWord:copy()
  return TranscriptWord.new {
    word = self.word,
    start = self.start,
    end_ = self.end_,
    probability = self.probability,
  }
end

function TranscriptWord:score()
  return self.probability
end

function TranscriptWord:to_table()
  return {
    word = self.word,
    start = self.start,
    ['end'] = self.end_,
    probability = self.probability,
  }
end
