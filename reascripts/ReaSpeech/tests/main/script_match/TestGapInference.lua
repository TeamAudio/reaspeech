package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('main/script_match/curation/GapInference')

--

local NEEDLES = {
  { guid = 'A' }, { guid = 'B' }, { guid = 'C' }, { guid = 'D' }, { guid = 'E' },
}

local function span(track, start_time, end_time)
  return { track_guid = track, start_time = start_time, end_time = end_time }
end

TestGapInference = {}

function TestGapInference:testWindowBetweenDirectNeighbors()
  local window = GapInference.window_for(NEEDLES, 2, {
    A = { span('T1', 10, 12) },
    C = { span('T1', 20, 22) },
  })

  lu.assertEquals(window.track_guid, 'T1')
  lu.assertEquals(window.start_time, 12)
  lu.assertEquals(window.end_time, 20)
end

-- Unclaimed needles between the target and its claim-bearing
-- neighbors are skipped over
function TestGapInference:testSkipsUnclaimedNeighbors()
  local window = GapInference.window_for(NEEDLES, 3, {
    A = { span('T1', 10, 12) },
    E = { span('T1', 30, 32) },
  })

  lu.assertEquals(window.start_time, 12)
  lu.assertEquals(window.end_time, 30)
end

function TestGapInference:testNoCommonTrackYieldsNil()
  lu.assertNil(GapInference.window_for(NEEDLES, 2, {
    A = { span('T1', 10, 12) },
    C = { span('T2', 20, 22) },
  }))
end

-- Takes out of script order (next starts before prev ends) offer no
-- positive window
function TestGapInference:testNegativeWindowYieldsNil()
  lu.assertNil(GapInference.window_for(NEEDLES, 2, {
    A = { span('T1', 20, 25) },
    C = { span('T1', 10, 12) },
  }))
end

function TestGapInference:testMissingNeighborYieldsNil()
  lu.assertNil(GapInference.window_for(NEEDLES, 1, {
    C = { span('T1', 20, 22) },
  }))
end

-- Several qualifying tracks: the tightest window is the strongest
-- evidence
function TestGapInference:testTightestWindowWins()
  local window = GapInference.window_for(NEEDLES, 2, {
    A = { span('T1', 10, 12), span('T2', 10, 11) },
    C = { span('T1', 40, 42), span('T2', 15, 16) },
  })

  lu.assertEquals(window.track_guid, 'T2')
  lu.assertEquals(window.end_time - window.start_time, 4)
end

--

os.exit(lu.LuaUnit.run())
