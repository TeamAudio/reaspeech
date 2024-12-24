package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

app = {}

local lu = require('luaunit')

require('mock_reaper')
require('Polo')
require('Trap')
require('source/SRTWriter')
require('source/Transcript')
require('source/TranscriptSegment')

--

reaper.GetMediaItemTake_Source = function () return {fileName = "test_audio.wav"} end
reaper.GetMediaSourceFileName = function (source) return source.fileName end

TestSRTWriter = {}

function TestSRTWriter:setUp()
  reaper.__test_setUp()
end

function TestSRTWriter.make_transcript()
  local t = Transcript.new()
  t:add_segment(TranscriptSegment.new {
    data = {start = 0, ['end'] = 1, text = 'hello'},
    item = {},
    take = {}
  })
  t:add_segment(TranscriptSegment.new {
    data = {start = 1, ['end'] = 2, text = 'world'},
    item = {},
    take = {}
  })
  t:update()
  return t
end

function TestSRTWriter:testFormatTime()
  lu.assertEquals(SRTWriter.format_time(0), '00:00:00,000')
  lu.assertEquals(SRTWriter.format_time(1), '00:00:01,000')
  lu.assertEquals(SRTWriter.format_time(1.5), '00:00:01,500')
  lu.assertEquals(SRTWriter.format_time(60), '00:01:00,000')
  lu.assertEquals(SRTWriter.format_time(60.5), '00:01:00,500')
  lu.assertEquals(SRTWriter.format_time(3600), '01:00:00,000')
  lu.assertEquals(SRTWriter.format_time(3600.5), '01:00:00,500')
end

function TestSRTWriter:testInit()
  local f = {}
  local writer = SRTWriter.new { file = f }
  lu.assertEquals(writer.file, f)
end

function TestSRTWriter:testInitNoFile()
  lu.assertErrorMsgContains('missing file', SRTWriter.new)
end

function TestSRTWriter:testWrite()
  local t = TestSRTWriter.make_transcript()
  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = SRTWriter.new { file = f }
  writer:write(t)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1\n00:00:00,000 --> 00:00:01,000\nhello\n\n2\n00:00:01,000 --> 00:00:02,000\nworld\n\n')
end

function TestSRTWriter:testXYCoordinates()
  local t = TestSRTWriter.make_transcript()
  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = SRTWriter.new {
    file = f,
    options = {
      coords_x1 = '1',
      coords_y1 = '2',
      coords_x2 = '3',
      coords_y2 = '4'
    }
  }
  writer:write(t)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1\n00:00:00,000 --> 00:00:01,000 X1:1 X2:3 Y1:2 Y2:4\nhello\n\n2\n00:00:01,000 --> 00:00:02,000 X1:1 X2:3 Y1:2 Y2:4\nworld\n\n')
end

function TestSRTWriter:testWriteSegment()
  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = SRTWriter.new { file = f }
  local segment = {
    get = function (self, key)
      if key == 'start' then
        return 0
      elseif key == 'end' then
        return 1
      elseif key == 'text' then
        return 'hello'
      end
    end
  }
  writer:write_segment(segment, 1)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1\n00:00:00,000 --> 00:00:01,000\nhello\n\n')
end

function TestSRTWriter:testWriteLine()
  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = SRTWriter.new { file = f }
  writer:write_line('hello', 1, 0, 1)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1\n00:00:00,000 --> 00:00:01,000\nhello\n\n')
end

--

os.exit(lu.LuaUnit.run())
