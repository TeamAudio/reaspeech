--[[

  SRTWriter.lua - SRT file writer

]]--

SRTWriter = Polo {
  TIME_FORMAT = '%02d:%02d:%02d,%03d',
}

function SRTWriter:init()
  assert(self.file, 'missing file')

  self.options = self.options or {}

  if self.options.coords_x1 then
    self.coords_x1 = self.options.coords_x1
  end
  if self.options.coords_y1 then
    self.coords_y1 = self.options.coords_y1
  end
  if self.options.coords_x2 then
    self.coords_x2 = self.options.coords_x2
  end
  if self.options.coords_y2 then
    self.coords_y2 = self.options.coords_y2
  end
end

SRTWriter.format_time = function (time)
  local milliseconds = math.floor(time * 1000) % 1000
  local seconds = math.floor(time) % 60
  local minutes = math.floor(time / 60) % 60
  local hours = math.floor(time / 3600)
  return string.format(SRTWriter.TIME_FORMAT, hours, minutes, seconds, milliseconds)
end

function SRTWriter:write(transcript)
  local sequence_number = 1
  for _, segment in pairs(transcript:get_segments()) do
    self:write_segment(segment, sequence_number)
    sequence_number = sequence_number + 1
  end
end

function SRTWriter:write_segment(segment, sequence_number)
  local start = segment:get('start')
  local end_ = segment:get('end')
  local text = segment:get('text')
  self:write_line(text, sequence_number, start, end_)
end

function SRTWriter:write_line(line, sequence_number, start, end_)
  local sequence_number_str = tostring(sequence_number)
  local start_str = SRTWriter.format_time(start)
  local end_str = SRTWriter.format_time(end_)
  self.file:write(sequence_number_str)
  self.file:write('\n')
  self.file:write(start_str)
  self.file:write(' --> ')
  self.file:write(end_str)
  self.file:write(self:coords())
  self.file:write('\n')
  self.file:write(line)
  self.file:write('\n')
  self.file:write('\n')
end

function SRTWriter:coords()
  local coords = {}

  if self.coords_x1 then
    table.insert(coords, 'X1:' .. self.coords_x1)
  end

  if self.coords_x2 then
    table.insert(coords, 'X2:' .. self.coords_x2)
  end

  if self.coords_y1 then
    table.insert(coords, 'Y1:' .. self.coords_y1)
  end

  if self.coords_y2 then
    table.insert(coords, 'Y2:' .. self.coords_y2)
  end

  if #coords == 0 then
    return ''
  end

  return ' ' .. table.concat(coords, ' ')
end
