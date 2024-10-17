package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

app = {
  trap = function(self, f)
    return xpcall(f, function(e) print(tostring(e)) end)
  end
}

local lu = require('luaunit')

require('json')
require('mock_reaper')
require('Polo')
require('source/Logging')
require('source/Transcript')
require('source/TranscriptAnnotations')
require('source/TranscriptSegment')
require('source/TranscriptWord')

--

local reaper_state = {
  markers = {},
  item_state_chunk = "",
  take_markers = {},
}

reaper.AddProjectMarker2 = function (proj, isrgn, pos, rgnend, name, wantidx, color)
  table.insert(reaper_state.markers, {
    proj = proj,
    isrgn = isrgn,
    pos = pos,
    rgnend = rgnend,
    name = name,
    wantidx = wantidx,
    color = color
  })
end

reaper.SetItemStateChunk = function (item, str, isundo)
  reaper_state.item_state_chunk = str
end

reaper.SetTakeMarker = function(take, index, name, pos, color)
  table.insert(reaper_state.take_markers, {
    take = take,
    idx = #reaper_state.take_markers + 1,
    name = name,
    pos = pos,
    color = color
  })
end

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

TestTranscriptMarkers = {
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

function TestTranscriptMarkers:setUp()
  reaper_state = {
    markers = {},
    item_state_chunk = "",
    take_markers = {},
  }
end

function TestTranscriptMarkers:testProjectMarkers()
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

  local m = TranscriptAnnotations.new { transcript = t }
  m:project_markers(0, false, false)
  lu.assertEquals(#reaper_state.markers, 2)
  lu.assertEquals(reaper_state.markers[1].proj, 0)
  lu.assertEquals(reaper_state.markers[1].isrgn, false)
  lu.assertEquals(reaper_state.markers[1].pos, 1.0)
  lu.assertEquals(reaper_state.markers[1].rgnend, 2.0)
  lu.assertEquals(reaper_state.markers[1].name, "test 1")
  lu.assertEquals(reaper_state.markers[1].wantidx, 1)
  lu.assertEquals(reaper_state.markers[2].proj, 0)
  lu.assertEquals(reaper_state.markers[2].isrgn, false)
  lu.assertEquals(reaper_state.markers[2].pos, 2.0)
  lu.assertEquals(reaper_state.markers[2].rgnend, 3.0)
  lu.assertEquals(reaper_state.markers[2].name, "test 2")
  lu.assertEquals(reaper_state.markers[2].wantidx, 2)
end

function TestTranscriptMarkers:testProjectRegions()
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

  local m = TranscriptAnnotations.new { transcript = t }
  m:project_regions(0, false)
  lu.assertEquals(#reaper_state.markers, 2)
  lu.assertEquals(reaper_state.markers[1].proj, 0)
  lu.assertEquals(reaper_state.markers[1].isrgn, true)
  lu.assertEquals(reaper_state.markers[1].pos, 1.0)
  lu.assertEquals(reaper_state.markers[1].rgnend, 2.0)
  lu.assertEquals(reaper_state.markers[1].name, "test 1")
  lu.assertEquals(reaper_state.markers[1].wantidx, 1)
  lu.assertEquals(reaper_state.markers[2].proj, 0)
  lu.assertEquals(reaper_state.markers[2].isrgn, true)
  lu.assertEquals(reaper_state.markers[2].pos, 2.0)
  lu.assertEquals(reaper_state.markers[2].rgnend, 3.0)
  lu.assertEquals(reaper_state.markers[2].name, "test 2")
  lu.assertEquals(reaper_state.markers[2].wantidx, 2)
end

function TestTranscriptMarkers:testTakeMarkers()
  local t = Transcript.new()
  t:add_segment(self.segment {
    id = 1,
    start = 1.0,
    end_ = 2.0,
    text = "test 1%",
    -- words = {
    --   self.word { word = "test", start = 1.0, end_ = 1.5, probability = 1.0 },
    --   self.word { word = "1%", start = 1.5, end_ = 2.0, probability = 0.5 }
    -- }
  })
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "test 2%",
    -- words = {
    --   self.word { word = "test", start = 2.0, end_ = 2.5, probability = 1.0 },
    --   self.word { word = "2%", start = 2.5, end_ = 3.0, probability = 0.5 }
    -- }
  })
  t:update()

  local m = TranscriptAnnotations.new { transcript = t }
  m:take_markers(false)
  lu.assertEquals(#reaper_state.take_markers, 2)
  lu.assertEquals(reaper_state.take_markers[1].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[1].idx, 1)
  lu.assertEquals(reaper_state.take_markers[1].name, "test 1%")
  lu.assertEquals(reaper_state.take_markers[1].pos, 1.0)
  lu.assertEquals(reaper_state.take_markers[1].color, 0x01030405)
  lu.assertEquals(reaper_state.take_markers[2].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[2].idx, 2)
  lu.assertEquals(reaper_state.take_markers[2].name, "test 2%")
  lu.assertEquals(reaper_state.take_markers[2].pos, 2.0)
  lu.assertEquals(reaper_state.take_markers[2].color, 0x01030405)
end

function TestTranscriptMarkers:testTakeMarkersWords()
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
  t:add_segment(self.segment {
    id = 2,
    start = 2.0,
    end_ = 3.0,
    text = "testy 2%",
    words = {
      self.word { word = "testy", start = 2.0, end_ = 2.5, probability = 1.0 },
      self.word { word = "2%", start = 2.5, end_ = 3.0, probability = 0.5 }
    }
  })
  t:update()

  local m = TranscriptAnnotations.new { transcript = t }
  m:take_markers(true)
  lu.assertEquals(#reaper_state.take_markers, 4)
  lu.assertEquals(reaper_state.take_markers[1].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[1].idx, 1)
  lu.assertEquals(reaper_state.take_markers[1].name, "test")
  lu.assertEquals(reaper_state.take_markers[1].pos, 1.0)
  lu.assertEquals(reaper_state.take_markers[1].color, 0x01030405)
  lu.assertEquals(reaper_state.take_markers[2].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[2].idx, 2)
  lu.assertEquals(reaper_state.take_markers[2].name, "1%")
  lu.assertEquals(reaper_state.take_markers[2].pos, 1.5)
  lu.assertEquals(reaper_state.take_markers[2].color, 0x01030405)
  lu.assertEquals(reaper_state.take_markers[3].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[3].idx, 3)
  lu.assertEquals(reaper_state.take_markers[3].name, "testy")
  lu.assertEquals(reaper_state.take_markers[3].pos, 2.0)
  lu.assertEquals(reaper_state.take_markers[3].color, 0x01030405)
  lu.assertEquals(reaper_state.take_markers[4].take, t.data[1].take)
  lu.assertEquals(reaper_state.take_markers[4].idx, 4)
  lu.assertEquals(reaper_state.take_markers[4].name, "2%")
  lu.assertEquals(reaper_state.take_markers[4].pos, 2.5)
  lu.assertEquals(reaper_state.take_markers[4].color, 0x01030405)
end

function TestTranscriptMarkers:testCreateNotesTrack()
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

  local m = TranscriptAnnotations.new { transcript = t }

  m:create_notes_track(false)
  lu.assertStrContains(reaper_state.item_state_chunk, [[<NOTES
|test 1%
>]])
  lu.assertStrContains(reaper_state.item_state_chunk, 'IMGRESOURCEFLAGS 11')
  m:create_notes_track(true)
  lu.assertStrContains(reaper_state.item_state_chunk, [[<NOTES
|1%
>]])
  lu.assertNotStrContains(reaper_state.item_state_chunk, 'IMGRESOURCEFLAGS 11')
end

--

os.exit(lu.LuaUnit.run())
