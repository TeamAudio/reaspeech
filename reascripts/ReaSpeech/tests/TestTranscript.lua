package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

app = {}

local lu = require('luaunit')

require('json')
require('mock_reaper')
require('source/Transcript')

--

reaper.GetCursorPosition = function () return 0 end
reaper.GetMediaItemInfo_Value = function (_, _) return 0 end
reaper.GetMediaItemTakeInfo_Value = function (_, _) return 0 end
reaper.GetMediaItemTake_Source = function () return {fileName = "test_audio.wav"} end
reaper.GetMediaSourceFileName = function (source) return source.fileName end
reaper.GetSelectedMediaItem = function (_, _) return {} end
reaper.GetSetMediaTrackInfo_String = function (_, _, _, _) end
reaper.GetTrack = function (_, _) return {} end
reaper.InsertTrackAtIndex = function (_, _) end
reaper.Main_OnCommand = function (_, _) end
reaper.SelectAllMediaItems = function (_, _) end
reaper.SetEditCurPos = function (_, _, _) end
reaper.SetMediaItemLength = function (_, _, _) end
reaper.SetMediaItemPosition = function (_, _, _) end
reaper.SetOnlyTrackSelected = function (_) end

reaper.GetItemStateChunk = function (item, str, isundo)
  return true, [[<ITEM
POSITION 0
SNAPOFFS 0
LENGTH 5
LOOP 1
ALLTAKES 0
FADEIN 1 0 0 1 0 0 0
FADEOUT 1 0 0 1 0 0 0
MUTE 0 0
SEL 0
IGUID {589DC296-5CC1-48A9-AE70-421A55B654E6}
IID 11
>]]
end

TestTranscript = {
  segment = function (data)
    local words = data.words
    data.words = nil
    data['end'] = data.end_
    data.end_ = nil
    return TranscriptSegment.new {
      data = data,
      item = {},
      take = {},
      words = words
    }
  end,

  word = TranscriptWord.new
}

function TestTranscript:setUp()
  function app:trap(f) return xpcall(f, function(e) print(tostring(e)) end) end

  reaper.__test_setUp()

  self.markers = {}
  reaper.AddProjectMarker2 = function (proj, isrgn, pos, rgnend, name, wantidx, color)
    table.insert(self.markers, {
      proj = proj,
      isrgn = isrgn,
      pos = pos,
      rgnend = rgnend,
      name = name,
      wantidx = wantidx,
      color = color
    })
  end

  self.item_state_chunk = ""
  reaper.SetItemStateChunk = function (item, str, isundo)
    self.item_state_chunk = str
  end
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
    text = "test 1"
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "test 2"
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

function TestTranscript:testCreateMarkers()
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
    end_ = 3.0,
    text = "test 2"
  })
  t:update()
  t:create_markers(0, false, false)
  lu.assertEquals(#self.markers, 2)
  lu.assertEquals(self.markers[1].proj, 0)
  lu.assertEquals(self.markers[1].isrgn, false)
  lu.assertEquals(self.markers[1].pos, 1.0)
  lu.assertEquals(self.markers[1].rgnend, 2.0)
  lu.assertEquals(self.markers[1].name, "test 1")
  lu.assertEquals(self.markers[1].wantidx, 1)
  lu.assertEquals(self.markers[2].proj, 0)
  lu.assertEquals(self.markers[2].isrgn, false)
  lu.assertEquals(self.markers[2].pos, 2.0)
  lu.assertEquals(self.markers[2].rgnend, 3.0)
  lu.assertEquals(self.markers[2].name, "test 2")
  lu.assertEquals(self.markers[2].wantidx, 2)
end

function TestTranscript:testCreateRegions()
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
    end_ = 3.0,
    text = "test 2"
  })
  t:update()
  t:create_markers(0, true, false)
  lu.assertEquals(#self.markers, 2)
  lu.assertEquals(self.markers[1].proj, 0)
  lu.assertEquals(self.markers[1].isrgn, true)
  lu.assertEquals(self.markers[1].pos, 1.0)
  lu.assertEquals(self.markers[1].rgnend, 2.0)
  lu.assertEquals(self.markers[1].name, "test 1")
  lu.assertEquals(self.markers[1].wantidx, 1)
  lu.assertEquals(self.markers[2].proj, 0)
  lu.assertEquals(self.markers[2].isrgn, true)
  lu.assertEquals(self.markers[2].pos, 2.0)
  lu.assertEquals(self.markers[2].rgnend, 3.0)
  lu.assertEquals(self.markers[2].name, "test 2")
  lu.assertEquals(self.markers[2].wantidx, 2)
end

function TestTranscript:testCreateNotesTrack()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1%",
    words = {
      self.word { word = "test", start = 1.0, end_ = 1.5, probability = 1.0 },
      self.word { word = "1%", start = 1.5, end_ = 2.0, probability = 0.5 }
    }
  })
  t:update()
  t:create_notes_track(false)
  lu.assertStrContains(self.item_state_chunk, [[<NOTES
|test 1%
>]])
  lu.assertStrContains(self.item_state_chunk, 'IMGRESOURCEFLAGS 11')
  t:create_notes_track(true)
  lu.assertStrContains(self.item_state_chunk, [[<NOTES
|1%
>]])
  lu.assertNotStrContains(self.item_state_chunk, 'IMGRESOURCEFLAGS 11')
end

function TestTranscript:testToJson()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1",
    words = {
      self.word { word = "test", start = 1.0, end_ = 1.5, probability = 1.0 },
      self.word { word = "1", start = 1.5, end_ = 2.0, probability = 0.5 }
    }
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "test 2",
    words = {
      self.word { word = "test", start = 2.0, end_ = 2.5, probability = 1.0 },
      self.word { word = "2", start = 2.5, end_ = 3.0, probability = 0.5 }
    }
  })
  t:update()
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
  local keys = {}
  for k, _ in pairs(parsed.segments[1]) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "file", "id", "start", "text", "words"})
  keys = {}
  for k, _ in pairs(parsed.segments[1].words[1]) do
    table.insert(keys, k)
  end
  table.sort(keys)
  lu.assertEquals(keys, {"end", "probability", "start", "word"})
end

--

os.exit(lu.LuaUnit.run())
