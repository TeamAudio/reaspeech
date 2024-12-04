package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

app = {}

local lu = require('luaunit')

require('mock_reaper')
require('Polo')
require('Trap')
require('source/CSVWriter')
require('source/Transcript')
require('source/TranscriptSegment')

--

reaper.GetMediaItemTake_Source = function () return {fileName = "test_audio.wav"} end
reaper.GetMediaSourceFileName = function (source) return source.fileName end

TestCSVWriter = {}

function TestCSVWriter:setUp()
  reaper.__test_setUp()
end

function TestCSVWriter.make_transcript()
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
  t:add_segment(TranscriptSegment.new {
    data = {start = 2, ['end'] = 3, text = 'something in "quotes"'},
    item = {},
    take = {}
  })
  t:update()

  return t
end

function TestCSVWriter:testFormatTime()
    lu.assertEquals(CSVWriter.format_time(0), '00:00:00,000')
    lu.assertEquals(CSVWriter.format_time(1), '00:00:01,000')
    lu.assertEquals(CSVWriter.format_time(1.5), '00:00:01,500')
    lu.assertEquals(CSVWriter.format_time(60), '00:01:00,000')
    lu.assertEquals(CSVWriter.format_time(60.5), '00:01:00,500')
    lu.assertEquals(CSVWriter.format_time(3600), '01:00:00,000')
    lu.assertEquals(CSVWriter.format_time(3600.5), '01:00:00,500')
  end

function TestCSVWriter:testInit()
  local f = {}
  local writer = CSVWriter.new { file = f }
end

function TestCSVWriter:testInitNoFile()
  lu.assertErrorMsgContains('missing file', CSVWriter.new)
end

function TestCSVWriter:testWrite()
  local t = TestCSVWriter.make_transcript()
  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = CSVWriter.new { file = f }
  writer:write(t)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1,"00:00:00,000","00:00:01,000","hello","test_audio.wav"\n2,"00:00:01,000","00:00:02,000","world","test_audio.wav"\n3,"00:00:02,000","00:00:03,000","something in ""quotes""","test_audio.wav"\n')
end

function TestCSVWriter:testCustomDelimiter()
  local t = TestCSVWriter.make_transcript()

  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = CSVWriter.new { file = f, delimiter = '\t' }
  writer:write(t)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '1\t"00:00:00,000"\t"00:00:01,000"\t"hello"\t"test_audio.wav"\n2\t"00:00:01,000"\t"00:00:02,000"\t"world"\t"test_audio.wav"\n3\t"00:00:02,000"\t"00:00:03,000"\t"something in ""quotes"""\t"test_audio.wav"\n')
end

function TestCSVWriter:testIncludeHeaderRow()
  local t = TestCSVWriter.make_transcript()

  local output = {}
  local f = {
    write = function (self, s)
      table.insert(output, s)
    end
  }
  local writer = CSVWriter.new { file = f, include_header_row = true }
  writer:write(t)
  local output_str = table.concat(output)
  lu.assertEquals(output_str, '"Sequence Number","Start Time","End Time","Text","File"\n1,"00:00:00,000","00:00:01,000","hello","test_audio.wav"\n2,"00:00:01,000","00:00:02,000","world","test_audio.wav"\n3,"00:00:02,000","00:00:03,000","something in ""quotes""","test_audio.wav"\n')
end

--

os.exit(lu.LuaUnit.run())
