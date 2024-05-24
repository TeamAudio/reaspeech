--[[

  CSVWriter.lua - Write CSV files

]]--

CSVWriter = {
  TIME_FORMAT = '%02d:%02d:%02d,%03d',
}

CSVWriter.__index = CSVWriter

CSVWriter.new = function (o)
  o = o or {}
  setmetatable(o, CSVWriter)
  o:init()
  return o
end

CSVWriter.format_time = function (time)
    local milliseconds = math.floor(time * 1000) % 1000
    local seconds = math.floor(time) % 60
    local minutes = math.floor(time / 60) % 60
    local hours = math.floor(time / 3600)
    return string.format(CSVWriter.TIME_FORMAT, hours, minutes, seconds, milliseconds)
  end

function CSVWriter:init()
  assert(self.file, 'missing file')
end

function CSVWriter:write(transcript)
  local sequence_number = 1
  for _, segment in pairs(transcript:get_segments()) do
    self:write_segment(segment, sequence_number)
    sequence_number = sequence_number + 1
  end
end

function CSVWriter:write_segment(segment, sequence_number)
  local start = segment:get('start')
  local end_ = segment:get('end')
  local text = segment:get('text')
  local file = segment:get_file_with_extension()
  self:write_line(text, sequence_number, start, end_, file)
end

function CSVWriter:write_line(line, sequence_number, start, end_, file)
  local fields = {
    sequence_number,
    CSVWriter.format_time(start),
    CSVWriter.format_time(end_),
    CSVWriter._quoted(line),
    CSVWriter._quoted(file),
  }

  self.file:write(table.concat(fields, ','))
  self.file:write('\n')
end

function CSVWriter._quoted(input_string)
  return table.concat({'"', input_string:gsub('"', '""'), '"'})
end
