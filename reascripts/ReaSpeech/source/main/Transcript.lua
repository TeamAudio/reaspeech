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
  end,

  __len = function(self)
    return #self.data
  end,
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

function Transcript:get_segment(row)
  return self.data[row]
end

function Transcript:get_segments()
  return self.data
end

function Transcript:has_words()
  for _, segment in pairs(self.init_data) do
    if segment.words then return true end
  end
  return false
end

function Transcript:segment_iterator()
  local segments = self.data
  local segment_count = #segments
  local segment_i = 1

  return function ()
    if segment_i <= segment_count then
      local segment = segments[segment_i]
      segment_i = segment_i + 1
      return segment
    end
  end
end

function Transcript:iterator(use_words)
  local segments = self.data
  local segment_count = #segments
  local count = 1
  local segment_i = 1
  local word_i = 1

  return function ()
    if segment_i <= segment_count then
      local segment = segments[segment_i]

      if not use_words then
        segment_i = segment_i + 1

        return {
          id = segment:get('id'),
          start = segment:get('start'),
          end_ = segment:get('end'),
          text = segment:get('text'),
          item = segment.item,
          take = segment.take,
          words = segment.words,
        }
      end

      local word = segment.words[word_i]
      local result = {
        id = count,
        start = word.start,
        end_ = word.end_,
        text = word.word,
        item = segment.item,
        take = segment.take,
      }

      if word_i < #segment.words then
        word_i = word_i + 1
      else
        word_i = 1
        segment_i = segment_i + 1
      end

      count = count + 1

      return result

    end
  end
end

function Transcript:set_name(name)
  self.name = name
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

  return {
    name = self.name,
    segments = segments
  }
end

function Transcript:to_json()
  return json.encode(self:to_table())
end

function Transcript.from_json(json_str)
  local data = json.decode(json_str)

  local t = Transcript.new {
    name = data.name or ''
  }

  for _, segment_data in pairs(data.segments) do
    local segment = TranscriptSegment.from_table(segment_data)
    t:add_segment(segment)
  end
  t:update()
  return t
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
