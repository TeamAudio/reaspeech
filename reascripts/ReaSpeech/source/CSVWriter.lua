--[[

  CSVWriter.lua - Write CSV files

]]--

CSVWriter = Polo {
  TIME_FORMAT = '%02d:%02d:%02d,%03d',
  DELIMITERS = {
    { char = ',',  name = 'Comma' },
    { char = ';',  name = 'Semicolon' },
    { char = '\t', name = 'Tab' },
  },

  new = function(options)
    options = options or {}
    return {
      file = options.file,
      delimiter = options.delimiter or ',',
      include_header_row = options.include_header_row or false,
    }
  end,
}

function CSVWriter:init()
  assert(self.file, 'missing file')
end

CSVWriter.format_time = function (time)
    local milliseconds = math.floor(time * 1000) % 1000
    local seconds = math.floor(time) % 60
    local minutes = math.floor(time / 60) % 60
    local hours = math.floor(time / 3600)
    return string.format(CSVWriter.TIME_FORMAT, hours, minutes, seconds, milliseconds)
  end

function CSVWriter:write(transcript)
  if self.include_header_row then
    self:write_header_row()
  end

  local sequence_number = 1
  for _, segment in pairs(transcript:get_segments()) do
    self:write_segment(segment, sequence_number)
    sequence_number = sequence_number + 1
  end
end

function CSVWriter:write_header_row()
  local fields = {
    CSVWriter._quoted('Sequence Number'),
    CSVWriter._quoted('Start Time'),
    CSVWriter._quoted('End Time'),
    CSVWriter._quoted('Text'),
    CSVWriter._quoted('File'),
  }

  self.file:write(table.concat(fields, self.delimiter))
  self.file:write('\n')
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
    CSVWriter._quoted(CSVWriter.format_time(start)),
    CSVWriter._quoted(CSVWriter.format_time(end_)),
    CSVWriter._quoted(line),
    CSVWriter._quoted(file),
  }

  self.file:write(table.concat(fields, self.delimiter))
  self.file:write('\n')
end

function CSVWriter._quoted(input_string)
  return table.concat({'"', input_string:gsub('"', '""'), '"'})
end
