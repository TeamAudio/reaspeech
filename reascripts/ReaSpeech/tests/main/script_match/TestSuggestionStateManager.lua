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

require('main/script_match/SuggestionStateManager')

--

local function suggestion(state, start_time, end_time, track_guid)
  return {
    state = state,
    start_time = start_time,
    end_time = end_time,
    track_guids = { track_guid or 'track-1' },
  }
end

--

TestNormalizeState = {}

function TestNormalizeState:testFoldsLegacyCurrentState()
  local s = SuggestionStateManager.normalize_state({ current_state = 'accepted' })
  lu.assertEquals(s.state, 'accepted')
  lu.assertNil(s.current_state)
end

function TestNormalizeState:testPrefersStateOverLegacyField()
  local s = SuggestionStateManager.normalize_state({ state = 'rejected', current_state = 'accepted' })
  lu.assertEquals(s.state, 'rejected')
  lu.assertNil(s.current_state)
end

function TestNormalizeState:testDefaultsToPending()
  lu.assertEquals(SuggestionStateManager.normalize_state({}).state, 'pending')
end

--

TestSpanKey = {}

function TestSpanKey:testIncludesTrackAndTimes()
  lu.assertEquals(
    SuggestionStateManager.span_key(suggestion('pending', 1.5, 2.5, 'g1')),
    'g1|1.5|2.5')
end

function TestSpanKey:testToleratesMissingTrack()
  lu.assertEquals(
    SuggestionStateManager.span_key({ start_time = 1, end_time = 2 }),
    '|1|2')
end

TestMergeReplacingPending = {}

function TestMergeReplacingPending:testDropsOldPendingKeepsDecided()
  local old_pending = suggestion('pending', 1, 2)
  local accepted = suggestion('accepted', 3, 4)
  local rejected = suggestion('rejected', 5, 6)
  local fresh = suggestion('pending', 1, 2)

  local merged = SuggestionStateManager.merge_replacing_pending(
    { old_pending, accepted, rejected },
    { fresh })

  lu.assertEquals(#merged, 3)
  lu.assertIs(merged[1], accepted)
  lu.assertIs(merged[2], rejected)
  lu.assertIs(merged[3], fresh)
end

function TestMergeReplacingPending:testIncomingDuplicateOfDecidedSpanDropped()
  local accepted = suggestion('accepted', 3, 4)
  local duplicate_of_accepted = suggestion('pending', 3, 4)
  local novel = suggestion('pending', 7, 8)

  local merged = SuggestionStateManager.merge_replacing_pending(
    { accepted },
    { duplicate_of_accepted, novel })

  lu.assertEquals(#merged, 2)
  lu.assertIs(merged[1], accepted)
  lu.assertIs(merged[2], novel)
end

function TestMergeReplacingPending:testDecidedBackfilledFromIncomingDuplicate()
  local accepted = suggestion('accepted', 3, 4)
  accepted.editorial_log = { 'decision history' }

  local duplicate = suggestion('pending', 3, 4)
  duplicate.file = 'VO Quill_03'
  duplicate.matching_text = 'regenerated text'

  local merged = SuggestionStateManager.merge_replacing_pending(
    { accepted }, { duplicate })

  lu.assertEquals(#merged, 1)
  lu.assertIs(merged[1], accepted)
  -- Missing field healed from the regenerated duplicate
  lu.assertEquals(accepted.file, 'VO Quill_03')
  -- Existing fields (including editorial state) untouched
  lu.assertEquals(accepted.state, 'accepted')
  lu.assertEquals(accepted.editorial_log, { 'decision history' })
  -- Absent fields fill; the span is the same match, so this is safe
  lu.assertEquals(accepted.matching_text, 'regenerated text')
end

function TestMergeReplacingPending:testSameSpanDifferentTrackIsNotADuplicate()
  local accepted = suggestion('accepted', 3, 4, 'track-1')
  local other_track = suggestion('pending', 3, 4, 'track-2')

  local merged = SuggestionStateManager.merge_replacing_pending(
    { accepted },
    { other_track })

  lu.assertEquals(#merged, 2)
end

function TestMergeReplacingPending:testEmptyExisting()
  local fresh = suggestion('pending', 1, 2)
  local merged = SuggestionStateManager.merge_replacing_pending({}, { fresh })
  lu.assertEquals(merged, { fresh })
end

function TestMergeReplacingPending:testEmptyIncomingKeepsOnlyDecided()
  local accepted = suggestion('accepted', 3, 4)
  local pending = suggestion('pending', 1, 2)

  local merged = SuggestionStateManager.merge_replacing_pending(
    { pending, accepted }, {})

  lu.assertEquals(#merged, 1)
  lu.assertIs(merged[1], accepted)
end

--

os.exit(lu.LuaUnit.run())
