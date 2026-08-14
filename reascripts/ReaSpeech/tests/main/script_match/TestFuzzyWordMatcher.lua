package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

-- Stubs for the REAPER/app environment
Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

TranscriptMetadataLayer = { key = 'transcript' }

local import_count = 0
local fake_segments = nil

TranscriptImporter = {
  import = function(_self, _path)
    import_count = import_count + 1
    return {
      has_words = function() return true end,
      get_segments = function() return fake_segments end,
    }
  end
}

require('main/script_match/curation/matchers/TextNormalizer')
require('main/script_match/curation/matchers/FuzzyAligner')
require('main/script_match/curation/matchers/FuzzyWordMatcher')

--

-- Build a segment whose words start at `t0`, one word per second.
-- Mirrors the real TranscriptSegment shape: JSON fields live in `data`
local function segment_at(t0, text)
  local words = {}
  local t = t0
  for word in text:gmatch('%S+') do
    table.insert(words, {
      word = word, start = t, end_ = t + 0.9, probability = 0.9,
    })
    t = t + 1
  end
  return { words = words, data = { file = 'fake' } }
end

local function make_workflow()
  local track = {
    guid = 'track-1',
    name = 'VO Track',
    metadata_layers = {
      { key = 'transcript', config = { transcript_file = 'fake.json' } },
    },
  }
  return {
    audio_tracks = function() return { track } end,
    audio_track = function(_self, _guid) return track end,
  }
end

local function make_matcher()
  return FuzzyWordMatcher.new {
    session_id = 'session-1',
    workflow = make_workflow(),
  }
end

local function drive_to_completion(matcher)
  for _ = 1, 20 do
    if matcher:is_ready() then return true end
  end
  return false
end

--

TestFuzzyWordMatcher = {}

function TestFuzzyWordMatcher:setUp()
  import_count = 0
  fake_segments = {
    segment_at(0, 'chatter before the takes'),
    segment_at(10, 'Jammed. Of course.'),
    segment_at(20, "Jammed! Of course."),
    segment_at(30, 'completely different words entirely'),
  }
end

function TestFuzzyWordMatcher:testSyncMatch()
  local matcher = make_matcher()
  local suggestions = matcher:match({ content = 'Jammed. Of course.' })

  lu.assertEquals(#suggestions, 2)
  lu.assertEquals(suggestions[1].confidence, 1.0)
  lu.assertEquals(suggestions[1].match_type, 'fuzzy')
  lu.assertEquals(suggestions[1].track_guids, { 'track-1' })
  lu.assertEquals(suggestions[1].file, 'fake')

  local starts = { suggestions[1].start_time, suggestions[2].start_time }
  table.sort(starts)
  lu.assertEquals(starts, { 10, 20 })
  lu.assertEquals(suggestions[1].end_time - suggestions[1].start_time > 0, true)
end

function TestFuzzyWordMatcher:testMatchingTextComesFromTranscript()
  local matcher = make_matcher()
  local suggestions = matcher:match({ content = 'jammed of course' })
  lu.assertStrContains(suggestions[1].matching_text, 'Jammed')
end

function TestFuzzyWordMatcher:testAsyncLifecycle()
  local matcher = make_matcher()
  lu.assertEquals(matcher:get_status(), 'idle')

  lu.assertIsTrue(matcher:start_async_generation({ content = 'Jammed. Of course.' }))
  lu.assertEquals(matcher:get_status(), 'running')

  lu.assertIsTrue(drive_to_completion(matcher))
  lu.assertEquals(matcher:get_status(), 'completed')
  lu.assertIsFalse(matcher:has_error())

  local results = matcher:get_results()
  lu.assertEquals(#results, 2)
end

function TestFuzzyWordMatcher:testStageDirectionOnlyNeedleCompletesEmpty()
  local matcher = make_matcher()
  lu.assertIsTrue(matcher:start_async_generation({ content = '[Gasps.]' }))
  lu.assertIsTrue(drive_to_completion(matcher))
  lu.assertEquals(matcher:get_status(), 'completed')
  lu.assertEquals(#matcher:get_results(), 0)
end

function TestFuzzyWordMatcher:testStageDirectionsStrippedFromNeedle()
  local matcher = make_matcher()
  local suggestions = matcher:match({ content = '{Deflated} Jammed. Of course.' })
  lu.assertEquals(#suggestions, 2)
  lu.assertEquals(suggestions[1].confidence, 1.0)
end

function TestFuzzyWordMatcher:testShortNeedleRequiresNearExact()
  local matcher = make_matcher()
  -- "jamd" is fuzzy-close to "Jammed" but a 1-token needle demands
  -- >= 0.8 for the normal tier; anything the rescue pass still offers
  -- must be explicitly marked a long shot below that bar
  for _, suggestion in ipairs(matcher:match({ content = 'jamd' })) do
    lu.assertIsTrue(suggestion.long_shot)
    lu.assertIsTrue(suggestion.confidence < 0.8)
  end

  local exact = matcher:match({ content = 'jammed' })
  lu.assertIsTrue(#exact > 0)
  lu.assertIsNil(exact[1].long_shot)
end

function TestFuzzyWordMatcher:testLongShotRescueWhenNothingClears()
  local matcher = make_matcher()
  -- Three of five needle words exist in the stream (score ~0.44): below
  -- the 0.5 normal floor, and the rescue pass surfaces it marked
  local suggestions = matcher:match({ content = 'jammed of course anteater marmalade' })

  lu.assertIsTrue(#suggestions > 0)
  for _, suggestion in ipairs(suggestions) do
    lu.assertIsTrue(suggestion.long_shot)
    lu.assertIsTrue(suggestion.confidence < 0.5)
  end
end

function TestFuzzyWordMatcher:testStrongMatchesNeverMarkedLongShot()
  local matcher = make_matcher()
  for _, suggestion in ipairs(matcher:match({ content = 'Jammed. Of course.' })) do
    lu.assertIsNil(suggestion.long_shot)
  end
end

function TestFuzzyWordMatcher:testAsyncLongShotParity()
  local matcher = make_matcher()
  lu.assertIsTrue(matcher:start_async_generation({ content = 'jammed of course anteater marmalade' }))
  lu.assertIsTrue(drive_to_completion(matcher))
  lu.assertEquals(matcher:get_status(), 'completed')

  local results = matcher:get_results()
  lu.assertIsTrue(#results > 0)
  lu.assertIsTrue(results[1].long_shot)
end

function TestFuzzyWordMatcher:testCancelResetsState()
  local matcher = make_matcher()
  matcher:start_async_generation({ content = 'Jammed. Of course.' })
  lu.assertIsTrue(matcher:cancel())
  lu.assertEquals(matcher:get_status(), 'idle')
  local results, err = matcher:get_results()
  lu.assertIsNil(results)
  lu.assertStrContains(err, 'not ready')
end

function TestFuzzyWordMatcher:testRestartAfterCompletion()
  local matcher = make_matcher()
  matcher:start_async_generation({ content = 'Jammed. Of course.' })
  drive_to_completion(matcher)
  lu.assertIsTrue(matcher:start_async_generation({ content = 'chatter before' }))
  lu.assertIsTrue(drive_to_completion(matcher))
  lu.assertIsTrue(#matcher:get_results() > 0)
end

function TestFuzzyWordMatcher:testStreamCacheAvoidsReimport()
  local matcher = make_matcher()
  matcher:match({ content = 'Jammed. Of course.' })
  lu.assertEquals(import_count, 1)
  matcher:match({ content = 'completely different words' })
  lu.assertEquals(import_count, 1)
end

function TestFuzzyWordMatcher:testTrackWithoutTranscriptSkipped()
  local track = { guid = 'track-2', name = 'No transcript', metadata_layers = {} }
  local matcher = FuzzyWordMatcher.new {
    session_id = 'session-1',
    workflow = {
      audio_tracks = function() return { track } end,
      audio_track = function(_self, _guid) return track end,
    },
  }
  lu.assertEquals(#matcher:match({ content = 'Jammed. Of course.' }), 0)
  lu.assertIsTrue(matcher:start_async_generation({ content = 'Jammed. Of course.' }))
  lu.assertIsTrue(drive_to_completion(matcher))
  lu.assertEquals(matcher:get_status(), 'completed')
end

--

os.exit(lu.LuaUnit.run())
