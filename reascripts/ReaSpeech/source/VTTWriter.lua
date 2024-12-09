--[[
  VTTWriter.lua - WebVTT file writer
]] --
VTTWriter = Polo {
    TIME_FORMAT = '%02d:%02d:%02d.%03d'
}

function VTTWriter:init()
    assert(self.file, 'missing file')
    self.options = self.options or {}

    -- Map options directly from passed in options
    self.vertical = self.options.vertical
    self.line = self.options.line
    self.position = self.options.position
    self.size = self.options.size
    self.align = self.options.align
end

VTTWriter.format_time = function(time)
    local milliseconds = math.floor(time * 1000) % 1000
    local seconds = math.floor(time) % 60
    local minutes = math.floor(time / 60) % 60
    local hours = math.floor(time / 3600)
    return string.format(VTTWriter.TIME_FORMAT, hours, minutes, seconds, milliseconds)
end

function VTTWriter:write(transcript)
    -- Write the required WEBVTT header
    self.file:write('WEBVTT\n\n')

    -- Write each segment
    for _, segment in pairs(transcript:get_segments()) do
        self:write_segment(segment)
    end
end

function VTTWriter:write_segment(segment)
    local start = segment:get('start')
    local end_ = segment:get('end')
    local text = segment:get('text')
    self:write_cue(text, start, end_)
end

function VTTWriter:write_cue(text, start, end_)
    local start_str = VTTWriter.format_time(start)
    local end_str = VTTWriter.format_time(end_)

    -- Write timestamp line with positioning if specified
    self.file:write(start_str)
    self.file:write(' --> ')
    self.file:write(end_str)
    self.file:write(self:settings())
    self.file:write('\n')

    -- Write cue text
    self.file:write(text)
    self.file:write('\n\n')
end

function VTTWriter:settings()
    local settings = {}

    if self.vertical then
        table.insert(settings, 'vertical:' .. self.vertical)
    end
    if self.line then
        table.insert(settings, 'line:' .. self.line)
    end
    if self.position then
        table.insert(settings, 'position:' .. self.position .. '%')
    end
    if self.size then
        table.insert(settings, 'size:' .. self.size .. '%')
    end
    if self.align then
        table.insert(settings, 'align:' .. self.align)
    end

    if #settings == 0 then
        return ''
    end
    return ' ' .. table.concat(settings, ' ')
end