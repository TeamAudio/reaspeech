--[[

  TranscriptSegment.lua - Transcript segment with a start/end and possible collection of words

]]--

TranscriptSegment = Polo {
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

function TranscriptSegment:init()
  assert(self.data, 'missing data')
  assert(self.item, 'missing item')
  assert(self.take, 'missing take')
  self.data = self._copy(self.data)
  self.data['file'] = self:get_file()
end

-- The source-time window that a take's visible section covers within its
-- media item, or nil when the window cannot be determined
TranscriptSegment.take_source_window = function(item, take)
  local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

  if not length or length <= 0 then
    return nil
  end

  local start_offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')

  if not playrate or playrate <= 0 then
    playrate = 1.0
  end

  return start_offset, start_offset + length * playrate
end

-- Whether any part of [start_time, end_time) is within the take's visible
-- section; true when the section cannot be determined
TranscriptSegment.overlaps_take_section = function(item, take, start_time, end_time)
  local window_start, window_end = TranscriptSegment.take_source_window(item, take)

  if not window_start then
    return true
  end

  return end_time > window_start and start_time < window_end
end

TranscriptSegment.from_whisper = function(segment, item, take)
  -- a source file can appear in many items; each item should only receive
  -- the segments its visible section can play
  if not TranscriptSegment.overlaps_take_section(item, take, segment.start, segment['end']) then
    return {}
  end

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

-- Returns nil for segments that fall outside their item's visible section;
-- items_by_guid is an optional prebuilt GUID lookup to avoid per-segment
-- scans of the project's media items
TranscriptSegment.from_table = function(data, items_by_guid)
  local segment_data = {}
  local item, take

  for k, v in pairs(data) do
    if k == 'item' then
      if items_by_guid then
        item = items_by_guid[v]
      else
        item = ReaUtil.get_item_by_guid(v)
      end
    elseif k == 'take' then
      take = reaper.GetMediaItemTakeByGUID(0, v)
    elseif k ~= 'words' then
      segment_data[k] = v
    end
  end

  -- transcripts saved before segments were clipped to their items can repeat
  -- the full segment list once per item sharing the source file; drop the
  -- copies that fall outside their item's visible section
  if item and take and segment_data.start and segment_data['end']
  and not TranscriptSegment.overlaps_take_section(item, take, segment_data.start, segment_data['end']) then
    return nil
  end

  local transcript_words
  if data.words then
    transcript_words = {}
    for _, word in pairs(data.words) do
      table.insert(transcript_words, TranscriptWord.from_table(word))
    end
  end

  return TranscriptSegment.new {
    data = segment_data,
    item = item or {},
    take = take or {},
    words = transcript_words
  }
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

function TranscriptSegment:get_file(include_extensions)
  include_extensions = include_extensions or false

  local file = ''
  Trap(function ()
    local source = reaper.GetMediaItemTake_Source(self.take)
    if source then
      local source_path = reaper.GetMediaSourceFileName(source)

      file = source_path:gsub(".*[\\/](.*)", "%1")

      if not include_extensions then
        file = file:gsub("(.*)[.].*", "%1")
      end
    end
  end)
  return file
end

function TranscriptSegment:get_file_with_extension()
  return self:get_file(true)
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

function TranscriptSegment:timeline_start_time()
  return reaper.GetMediaItemInfo_Value(self.item, 'D_POSITION')
    + self.start
    - reaper.GetMediaItemTakeInfo_Value(self.take, 'D_STARTOFFS')
end

function TranscriptSegment:timeline_end_time()
  return reaper.GetMediaItemInfo_Value(self.item, 'D_POSITION')
    + self.end_
    - reaper.GetMediaItemTakeInfo_Value(self.take, 'D_STARTOFFS')
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

function TranscriptSegment:to_json()
  return json.encode(self:to_table())
end

function TranscriptSegment:to_table()
  local result = self._copy(self.data)
  if self.words then
    result['words'] = {}
    for _, word in pairs(self.words) do
      table.insert(result['words'], word:to_table())
    end
  end

  result.item = ReaUtil.get_item_info(self.item, 'GUID')
  result.take = ReaUtil.get_take_info(self.take, 'GUID')
  return result
end

function TranscriptSegment:select_in_timeline(offset)
  offset = offset or 0
  local start = self.start + offset
  local end_ = self.end_ + offset

  reaper.GetSet_LoopTimeRange(true, true, start, end_, false)
end
