package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

Trap = function(f)
  return (pcall(f))
end

-- Mutable project state driven by the tests; the reaper stub must exist
-- before ReaIter is required, because ReaIter binds functions at load.
local STATE

reaper = {
  CountTracks = function() return #STATE.tracks end,
  GetTrack = function(_, i) return STATE.tracks[i + 1] end,
  CountTrackMediaItems = function(track) return #track.items end,
  GetTrackMediaItem = function(track, i) return track.items[i + 1] end,
  GetTrackGUID = function(track) return track.guid end,
  GetActiveTake = function(item) return item.take end,
  GetMediaItemInfo_Value = function(item, key) return item[key] or 0 end,
  GetMediaItemTakeInfo_Value = function(take, key) return take[key] or 0 end,
  GetMediaItemTake_Source = function(take) return take.source end,
  GetMediaSourceFileName = function(source) return source end,
  GetMediaTrackInfo_Value = function(track, key) return track[key] or 0 end,
  SetMediaTrackInfo_Value = function(track, key, value) track[key] = value end,
  GetCursorPosition = function() return STATE.cursor end,
  SetEditCurPos = function(pos) STATE.cursor = pos end,
  GetPlayState = function() return STATE.play_state end,
  GetPlayPosition = function() return STATE.play_position end,
  Main_OnCommand = function(command)
    table.insert(STATE.commands, command)
    if command == 1007 then STATE.play_state = 1 end
    if command == 1016 then STATE.play_state = 0 end
  end,
}

require('libs/ReaIter')
require('libs/ReaUtil')
require('libs/IntervalFunction')
require('libs/PathUtil')
require('ui/ReaperConstants')
require('main/script_match/SuggestionTimeline')
require('main/script_match/curation/SuggestionAudioPreview')

--

local function make_workflow()
  local workflow = { nudgeables = {} }
  function workflow:register_nudgeable(interval, stop_check)
    table.insert(self.nudgeables, { interval = interval, stop_check = stop_check })
  end
  function workflow:pump(time)
    for _, nudgeable in ipairs(self.nudgeables) do
      if not nudgeable.stop_check() then
        nudgeable.interval:react(time)
      end
    end
  end
  return workflow
end

local function setup_project()
  local item = {
    take = { source = '/media/VO Nova.wav', D_STARTOFFS = 2.0, D_PLAYRATE = 1 },
    D_POSITION = 100.0,
    D_LENGTH = 50.0,
  }
  local track = { guid = 'guid-1', items = { item }, I_SOLO = 0 }
  local other = { guid = 'guid-2', items = {}, I_SOLO = 1 }

  STATE = {
    tracks = { track, other },
    cursor = 55.0,
    commands = {},
    play_state = 0,
    play_position = 0,
  }

  return track, other, item
end

local function suggestion_with(overrides)
  local suggestion = {
    start_time = 5.0,
    end_time = 8.0,
    file = 'VO Nova',
    track_guids = { 'guid-1' },
  }
  for key, value in pairs(overrides or {}) do
    suggestion[key] = value
  end
  return suggestion
end

local function count_commands(command)
  local count = 0
  for _, c in ipairs(STATE.commands) do
    if c == command then count = count + 1 end
  end
  return count
end

local function make_preview(workflow)
  return SuggestionAudioPreview.new { workflow = workflow or make_workflow() }
end

--

TestSuggestionAudioPreview = {}

function TestSuggestionAudioPreview:testPlayMapsFileTimeToTimeline()
  local track, other = setup_project()
  local preview = make_preview()
  local suggestion = suggestion_with()

  lu.assertIsTrue(preview:play(suggestion))
  -- timeline = item position + (file time - start offset): 100 + (5 - 2)
  lu.assertEquals(STATE.cursor, 103.0)
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_PLAY), 1)
  lu.assertIsTrue(preview:is_active(suggestion))
  lu.assertEquals(track.I_SOLO, 1)
  lu.assertEquals(other.I_SOLO, 0)
end

function TestSuggestionAudioPreview:testResolveIncludesItemBounds()
  setup_project()
  local range = SuggestionTimeline.resolve(suggestion_with())
  lu.assertEquals(range.item_start, 100.0)
  lu.assertEquals(range.item_end, 150.0) -- position + length
end

function TestSuggestionAudioPreview:testPlayrateAffectsMapping()
  local track = setup_project()
  track.items[1].take.D_PLAYRATE = 2
  local preview = make_preview()

  lu.assertIsTrue(preview:play(suggestion_with()))
  lu.assertEquals(STATE.cursor, 101.5) -- 100 + (5 - 2) / 2
end

function TestSuggestionAudioPreview:testStopsAndRestoresAfterRangePlays()
  local track, other = setup_project()
  local workflow = make_workflow()
  local preview = make_preview(workflow)
  local suggestion = suggestion_with()
  preview:play(suggestion)

  STATE.play_position = 104.0
  workflow:pump(1)
  lu.assertIsTrue(preview:is_active(suggestion))

  STATE.play_position = 106.2 -- past end (106) + padding
  workflow:pump(2)
  lu.assertIsFalse(preview:is_active(suggestion))
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_STOP), 1)
  lu.assertEquals(track.I_SOLO, 0)
  lu.assertEquals(other.I_SOLO, 1)
  lu.assertEquals(STATE.cursor, 55.0)
end

function TestSuggestionAudioPreview:testUserStopRestoresWithoutSecondStop()
  local track, other = setup_project()
  local workflow = make_workflow()
  local preview = make_preview(workflow)
  preview:play(suggestion_with())

  STATE.play_state = 0 -- user hit stop in REAPER
  workflow:pump(1)
  lu.assertIsFalse(preview:is_active(suggestion_with()))
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_STOP), 0)
  lu.assertEquals(other.I_SOLO, 1)
  lu.assertEquals(STATE.cursor, 55.0)
end

function TestSuggestionAudioPreview:testExplicitStopRestores()
  local track, other = setup_project()
  local preview = make_preview()
  local suggestion = suggestion_with()
  preview:play(suggestion)

  preview:stop()
  lu.assertIsFalse(preview:is_active(suggestion))
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_STOP), 1)
  lu.assertEquals(track.I_SOLO, 0)
  lu.assertEquals(other.I_SOLO, 1)
end

function TestSuggestionAudioPreview:testUnknownTrackReturnsFalse()
  setup_project()
  local preview = make_preview()

  lu.assertIsFalse(preview:play(suggestion_with({ track_guids = { 'nope' } })))
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_PLAY), 0)
end

function TestSuggestionAudioPreview:testPicksItemCoveringTheTime()
  local track = setup_project()
  -- Same source file split across two items with different offsets
  track.items[1].take.D_STARTOFFS = 0
  track.items[1].D_LENGTH = 4.0
  track.items[2] = {
    take = { source = '/media/VO Nova.wav', D_STARTOFFS = 4.0, D_PLAYRATE = 1 },
    D_POSITION = 200.0,
    D_LENGTH = 10.0,
  }
  local preview = make_preview()

  lu.assertIsTrue(preview:play(suggestion_with())) -- start_time 5 is in item 2
  lu.assertEquals(STATE.cursor, 201.0) -- 200 + (5 - 4)
end

function TestSuggestionAudioPreview:testMatchesSourceFile()
  local track = setup_project()
  track.items[2] = {
    take = { source = '/media/VO Other.wav', D_STARTOFFS = 2.0, D_PLAYRATE = 1 },
    D_POSITION = 300.0,
    D_LENGTH = 50.0,
  }
  local preview = make_preview()

  lu.assertIsTrue(preview:play(suggestion_with({ file = 'VO Other' })))
  lu.assertEquals(STATE.cursor, 303.0)
end

function TestSuggestionAudioPreview:testFallsBackToFileMatchOutsideVisibleSection()
  local track = setup_project()
  track.items[1].take.D_STARTOFFS = 20.0 -- take starts after the suggestion time
  local preview = make_preview()

  lu.assertIsTrue(preview:play(suggestion_with())) -- approximate is better than nothing
  lu.assertEquals(STATE.cursor, 85.0) -- 100 + (5 - 20)
end

function TestSuggestionAudioPreview:testPlayingSecondSuggestionStopsFirst()
  setup_project()
  local preview = make_preview()
  local first = suggestion_with()
  local second = suggestion_with({ start_time = 6.0, end_time = 9.0 })

  preview:play(first)
  preview:play(second)
  lu.assertIsFalse(preview:is_active(first))
  lu.assertIsTrue(preview:is_active(second))
  lu.assertEquals(count_commands(ReaperConstants.TRANSPORT_STOP), 1)
end

--

os.exit(lu.LuaUnit.run())
