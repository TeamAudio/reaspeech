package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

app = {}

local lu = require('luaunit')

require('json')
require('mock_reaper')
require('Polo')
require('ReaIter')
require('ReaUtil')
require('source/Transcript')
require('source/TranscriptSegment')
require('source/TranscriptWord')

--

reaper.GetMediaItemTake_Source = function () return {fileName = "test_audio.wav"} end
reaper.GetMediaSourceFileName = function (source) return source.fileName end

TestTranscript = {
  segment = function (data)
    local words = data.words
    data.words = nil
    data['end'] = data.end_
    data.end_ = nil
    return TranscriptSegment.new {
      data = data,
      item = data.item or 'media_item_userdata',
      take = data.take or 'take_userdata',
      words = words
    }
  end,

  word = TranscriptWord.new
}

function TestTranscript:setUp()
  function app:trap(f) return xpcall(f, function(e) print(tostring(e)) end) end

  reaper.__test_setUp()
end

function TestTranscript:make_transcript()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1",
    words = {
      self.word { word = "test", start = 1.0, end_ = 1.5, probability = 1.0 },
      self.word { word = "1", start = 1.5, end_ = 2.0, probability = 0.5 }
    },
    item = 'media_item_userdata1',
    take = 'take_userdata1',
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "test 2",
    words = {
      self.word { word = "test", start = 2.0, end_ = 2.5, probability = 1.0 },
      self.word { word = "2", start = 2.5, end_ = 3.0, probability = 0.5 }
    },
    item = 'media_item_userdata2',
    take = 'take_userdata2',
  })
  t:update()
  return t
end

function TestTranscript:testInit()
  local t = Transcript.new()
  lu.assertEquals(t.init_data, {})
  lu.assertEquals(t.filtered_data, {})
  lu.assertEquals(t.data, {})
  lu.assertEquals(t.search, '')
end

function TestTranscript:testClear()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test"
  })
  t.search = 'test'
  t:update()
  lu.assertEquals(t:has_segments(), true)
  lu.assertEquals(#t.init_data, 1)
  lu.assertEquals(#t.filtered_data, 1)
  lu.assertEquals(#t.data, 1)
  t:clear()
  lu.assertEquals(t:has_segments(), false)
  lu.assertEquals(#t.init_data, 0)
  lu.assertEquals(#t.filtered_data, 0)
  lu.assertEquals(#t.data, 0)
  lu.assertEquals(t.search, '')
end

function TestTranscript:testColumnOrder()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test",
    avg_logprob = 0.5
  })
  local columns = t:get_columns()
  lu.assertEquals(columns, {"id", "start", "end", "text", "score", "file", "avg_logprob"})
end

function TestTranscript:testFileColumn()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test"
  })
  t:update()
  local segments = t:get_segments()
  lu.assertEquals(segments[1]:get_file(), "test_audio")
  lu.assertEquals(segments[1]:get('file'), "test_audio")
end

function TestTranscript:testIteratorIteratingSegments()
  local t = self:make_transcript()

  local results = {}
  for element in t:iterator(false) do
    table.insert(results, element)
  end

  lu.assertEquals(#results, 2)
  lu.assertEquals(results[1].id, 1)
  lu.assertEquals(results[1].start, 1.0)
  lu.assertEquals(results[1].end_, 2.0)
  lu.assertEquals(results[1].text, "test 1")
  lu.assertEquals(results[2].id, 2)
  lu.assertEquals(results[2].start, 2.0)
  lu.assertEquals(results[2].end_, 3.0)
  lu.assertEquals(results[2].text, "test 2")
end

function TestTranscript:testIteratorIteratingWords()
  local t = self:make_transcript()

  local results = {}
  for element in t:iterator(true) do
    table.insert(results, element)
  end

  lu.assertEquals(#results, 4)
  lu.assertEquals(results[1].id, 1)
  lu.assertEquals(results[1].start, 1.0)
  lu.assertEquals(results[1].end_, 1.5)
  lu.assertEquals(results[1].text, "test")
  lu.assertEquals(results[2].id, 2)
  lu.assertEquals(results[2].start, 1.5)
  lu.assertEquals(results[2].end_, 2.0)
  lu.assertEquals(results[2].text, "1")
  lu.assertEquals(results[3].id, 3)
  lu.assertEquals(results[3].start, 2.0)
  lu.assertEquals(results[3].end_, 2.5)
  lu.assertEquals(results[3].text, "test")
  lu.assertEquals(results[4].id, 4)
  lu.assertEquals(results[4].start, 2.5)
  lu.assertEquals(results[4].end_, 3.0)
  lu.assertEquals(results[4].text, "2")
end

function TestTranscript:testSearch()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1"
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    ['end'] = 3.0,
    text = "test 2"
  })
  t.search = 'test 2'
  t:update()
  lu.assertEquals(#t.init_data, 2)
  lu.assertEquals(#t.filtered_data, 1)
  lu.assertEquals(#t.data, 1)
  local segments = t:get_segments()
  lu.assertEquals(segments[1]:get('id'), 2)
end

function TestTranscript:testSort()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1",
    tokens = {3, 2, 1},
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "test 2",
    tokens = {1, 2, 3},
  })
  t:update()
  t:sort('id', true)
  local segments = t:get_segments()
  lu.assertEquals(segments[1]:get('id'), 1)
  lu.assertEquals(segments[2]:get('id'), 2)
  t:sort('id', false)
  segments = t:get_segments()
  lu.assertEquals(segments[1]:get('id'), 2)
  lu.assertEquals(segments[2]:get('id'), 1)
  t:sort('tokens', true)
  segments = t:get_segments()
  lu.assertEquals(segments[1]:get('id'), 2)
  lu.assertEquals(segments[2]:get('id'), 1)
end

function TestTranscript:testDefaultHide()
  lu.assertFalse(TranscriptSegment.default_hide('id'))
  lu.assertTrue(TranscriptSegment.default_hide('seek'))
end

function TestTranscript:testSegmentScore()
  local s = self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test won",
    words = {
      self.word { word = "test", start = 1.0, end_ = 1.5, probability = 1.0 },
      self.word { word = "won", start = 1.5, end_ = 2.0, probability = 0.5 }
    }
  }
  lu.assertAlmostEquals(s:score(), 0.75, 0.01)
  lu.assertAlmostEquals(s:get('score'), 0.75, 0.01)
end

function TestTranscript:testSetWords()
  local s = self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "the fox",
    words = {
      self.word { word = "the", start = 1.0, end_ = 1.5, probability = 1.0 },
      self.word { word = "fox", start = 1.5, end_ = 2.0, probability = 0.5 }
    }
  }
  lu.assertEquals(s.words[2].word, "fox")
  lu.assertEquals(s:get('text'), "the fox")
  lu.assertAlmostEquals(s:get('score'), 0.75, 0.01)
  s:set_words({
    self.word { word = "the", start = 1.0, end_ = 1.25, probability = 1.0 },
    self.word { word = "quick", start = 1.25, end_ = 1.5, probability = 1.0 },
    self.word { word = "brown", start = 1.5, end_ = 1.75, probability = 1.0 },
    self.word { word = "fox", start = 1.75, end_ = 2.0, probability = 1.0 }
  })
  lu.assertEquals(s.words[2].word, "quick")
  lu.assertEquals(s:get('text'), "the quick brown fox")
  lu.assertAlmostEquals(s:get('score'), 1.0, 0.01)
end

function TestTranscript:testMergeWords()
  local words = {
    self.word { word = "rene", start = 1.0, end_ = 1.5, probability = 1.0 },
    self.word { word = "gade", start = 1.5, end_ = 2.0, probability = 0.5 }
  }
  TranscriptSegment.merge_words(words, 1, 2)
  lu.assertEquals(#words, 1)
  lu.assertEquals(words[1].word, "renegade")
  lu.assertEquals(words[1].start, 1.0)
  lu.assertEquals(words[1].end_, 2.0)
  lu.assertAlmostEquals(words[1].probability, 0.75, 0.01)
end

function TestTranscript:testSplitWords()
  local words = {
    self.word { word = "renegade", start = 1.0, end_ = 2.0, probability = 1.0 }
  }
  TranscriptSegment.split_word(words, 1)
  lu.assertEquals(#words, 2)
  lu.assertEquals(words[1].word, "rene")
  lu.assertEquals(words[1].start, 1.0)
  lu.assertEquals(words[1].end_, 1.5)
  lu.assertAlmostEquals(words[1].probability, 1.0, 0.01)
  lu.assertEquals(words[2].word, "gade")
  lu.assertEquals(words[2].start, 1.5)
  lu.assertEquals(words[2].end_, 2.0)
  lu.assertAlmostEquals(words[2].probability, 1.0, 0.01)
end

function TestTranscript:testToJson()
  local fake_vals = {
    media_item_userdata1 = "media_item_guid1",
    media_item_userdata2 = "media_item_guid2",
    take_userdata1 = "take_guid1",
    take_userdata2 = "take_guid2",
  }

  local fake_getset = function(item_userdata, param)
    if param == 'GUID' then
      return true, fake_vals[item_userdata]
    end
  end
  reaper.GetSetMediaItemInfo_String = fake_getset
  reaper.GetSetMediaItemTakeInfo_String = fake_getset

  local t = TestTranscript:make_transcript()
  local result = t:to_json()
  local parsed = json.decode(result)
  lu.assertEquals(parsed.segments[1].id, 1)
  lu.assertEquals(parsed.segments[1].start, 1.0)
  lu.assertEquals(parsed.segments[1]['end'], 2.0)
  lu.assertEquals(parsed.segments[1].text, "test 1")
  lu.assertEquals(parsed.segments[1].words[1].word, "test")
  lu.assertEquals(parsed.segments[1].words[1].start, 1.0)
  lu.assertEquals(parsed.segments[1].words[1]['end'], 1.5)
  lu.assertEquals(parsed.segments[1].words[1].probability, 1.0)
  lu.assertEquals(parsed.segments[1].words[2].word, "1")
  lu.assertEquals(parsed.segments[1].words[2].start, 1.5)
  lu.assertEquals(parsed.segments[1].words[2]['end'], 2.0)
  lu.assertEquals(parsed.segments[1].words[2].probability, 0.5)
  lu.assertEquals(parsed.segments[1].item, "media_item_guid1")
  lu.assertEquals(parsed.segments[1].take, "take_guid1")
  lu.assertEquals(parsed.segments[2].id, 2)
  lu.assertEquals(parsed.segments[2].start, 2.0)
  lu.assertEquals(parsed.segments[2]['end'], 3.0)
  lu.assertEquals(parsed.segments[2].text, "test 2")
  lu.assertEquals(parsed.segments[2].words[1].word, "test")
  lu.assertEquals(parsed.segments[2].words[1].start, 2.0)
  lu.assertEquals(parsed.segments[2].words[1]['end'], 2.5)
  lu.assertEquals(parsed.segments[2].words[1].probability, 1.0)
  lu.assertEquals(parsed.segments[2].words[2].word, "2")
  lu.assertEquals(parsed.segments[2].words[2].start, 2.5)
  lu.assertEquals(parsed.segments[2].words[2]['end'], 3.0)
  lu.assertEquals(parsed.segments[2].words[2].probability, 0.5)
  lu.assertEquals(parsed.segments[2].item, "media_item_guid2")
  lu.assertEquals(parsed.segments[2].take, "take_guid2")
  local keys = {}
  for k, _ in pairs(parsed.segments[1]) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "file", "id", "item", "start", "take", "text", "words"})
  keys = {}
  for k, _ in pairs(parsed.segments[1].words[1]) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "probability", "start", "word"})
end

function TestTranscript:testSegmentToJson()
  local fake_vals = {
    media_item_userdata1 = "media_item_guid1",
    media_item_userdata2 = "media_item_guid2",
    take_userdata1 = "take_guid1",
    take_userdata2 = "take_guid2",
  }

  local fake_getset = function(item_userdata, param)
    if param == 'GUID' then
      return true, fake_vals[item_userdata]
    end
  end
  reaper.GetSetMediaItemInfo_String = fake_getset
  reaper.GetSetMediaItemTakeInfo_String = fake_getset

  local t = TestTranscript:make_transcript()
  local result = t:get_segments()[1]:to_json()
  local parsed = json.decode(result)
  lu.assertEquals(parsed.id, 1)
  lu.assertEquals(parsed.start, 1.0)
  lu.assertEquals(parsed['end'], 2.0)
  lu.assertEquals(parsed.text, "test 1")
  lu.assertEquals(parsed.words[1].word, "test")
  lu.assertEquals(parsed.words[1].start, 1.0)
  lu.assertEquals(parsed.words[1]['end'], 1.5)
  lu.assertEquals(parsed.words[1].probability, 1.0)
  lu.assertEquals(parsed.words[2].word, "1")
  lu.assertEquals(parsed.words[2].start, 1.5)
  lu.assertEquals(parsed.words[2]['end'], 2.0)
  lu.assertEquals(parsed.words[2].probability, 0.5)
  lu.assertEquals(parsed.item, "media_item_guid1")
  lu.assertEquals(parsed.take, "take_guid1")
  local keys = {}
  for k, _ in pairs(parsed) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "file", "id", "item", "start", "take", "text", "words"})
  keys = {}
  for k, _ in pairs(parsed.words[1]) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "probability", "start", "word"})
end

function TestTranscript:TestFromJson()
  reaper.CountMediaItems = function() return 2 end
  reaper.GetMediaItem = function(_, idx)
    if idx == 0 then
      return "media_item_userdata1"
    elseif idx == 1 then
      return "media_item_userdata2"
    end
  end

  ReaIter.each_media_item = ReaIter._make_iterator(reaper.CountMediaItems, reaper.GetMediaItem)

  reaper.GetMediaItemTakeByGUID = function(_, guid)
    -- print('take guid: ' .. guid .. '\n')
    if guid == "take_guid1" then
      return "take_userdata1"
    elseif guid == "take_guid2" then
      return "take_userdata2"
    end
  end

  local fake_vals = {
    media_item_userdata1 = "media_item_guid1",
    media_item_userdata2 = "media_item_guid2",
    take_userdata1 = "take_guid1",
    take_userdata2 = "take_guid2",
  }

  local fake_getset = function(item_userdata, param)
    if param == 'GUID' then
      return true, fake_vals[item_userdata]
    end
  end
  reaper.GetSetMediaItemInfo_String = fake_getset
  reaper.GetSetMediaItemTakeInfo_String = fake_getset

  local json_str = [[
    {
      "segments": [
        {
          "id": 1,
          "start": 1.0,
          "end": 2.0,
          "text": "test 1",
          "words": [
            {
              "word": "test",
              "start": 1.0,
              "end": 1.5,
              "probability": 1.0
            },
            {
              "word": "1",
              "start": 1.5,
              "end": 2.0,
              "probability": 0.5
            }
          ],
          "item": "media_item_guid1",
          "take": "take_guid1"
        },
        {
          "id": 2,
          "start": 2.0,
          "end": 3.0,
          "text": "test 2",
          "words": [
            {
              "word": "test",
              "start": 2.0,
              "end": 2.5,
              "probability": 1.0
            },
            {
              "word": "2",
              "start": 2.5,
              "end": 3.0,
              "probability": 0.5
            }
          ],
          "item": "media_item_guid2",
          "take": "take_guid2"
        }
      ]
    }
  ]]

  local t = Transcript.from_json(json_str)
  lu.assertEquals(#t.init_data, 2)
  lu.assertEquals(#t.filtered_data, 2)
  lu.assertEquals(#t.data, 2)
  lu.assertEquals(t.init_data[1].data.id, 1)
  lu.assertEquals(t.init_data[1].data.start, 1.0)
  lu.assertEquals(t.init_data[1].words[1].word, "test")
  lu.assertEquals(t.init_data[1].words[1].start, 1.0)
  lu.assertEquals(t.init_data[1].words[1].end_, 1.5)
  lu.assertEquals(t.init_data[1].words[1].probability, 1.0)
  lu.assertEquals(t.init_data[1].words[2].word, "1")
  lu.assertEquals(t.init_data[1].words[2].start, 1.5)
  lu.assertEquals(t.init_data[1].words[2].end_, 2.0)
  lu.assertEquals(t.init_data[1].words[2].probability, 0.5)
  lu.assertEquals(t.init_data[1].item, "media_item_userdata1")
  lu.assertEquals(t.init_data[1].take, "take_userdata1")
  lu.assertEquals(t.init_data[2].data.id, 2)
  lu.assertEquals(t.init_data[2].data.start, 2.0)
  lu.assertEquals(t.init_data[2].words[1].word, "test")
  lu.assertEquals(t.init_data[2].words[1].start, 2.0)
  lu.assertEquals(t.init_data[2].words[1].end_, 2.5)
  lu.assertEquals(t.init_data[2].words[1].probability, 1.0)
  lu.assertEquals(t.init_data[2].words[2].word, "2")
  lu.assertEquals(t.init_data[2].words[2].start, 2.5)
  lu.assertEquals(t.init_data[2].words[2].end_, 3.0)
  lu.assertEquals(t.init_data[2].words[2].probability, 0.5)
  lu.assertEquals(t.init_data[2].item, "media_item_userdata2")
  lu.assertEquals(t.init_data[2].take, "take_userdata2")
end

--

os.exit(lu.LuaUnit.run())
