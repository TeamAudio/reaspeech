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

TranscriptMetadataLayer = { key = 'transcript' }

PathUtil = {
  get_filename = function(path) return path:match('[^/]+$') or path end,
}

-- In-memory Storage double: one table per ProjectJSON path
local stores

Storage = {
  ProjectJSON = function(path, _opts)
    return {
      table = function(_self, key, default)
        local store_key = path .. '\0' .. key
        if stores[store_key] == nil then stores[store_key] = default end
        return {
          get = function() return stores[store_key] end,
          set = function(_s, value) stores[store_key] = value end,
        }
      end,
    }
  end,
}

require('main/script_match/curation/NeedleDiagnosis')

--

local probe_results, probe_calls

local function make_diagnosis(scan_transcripts)
  local track = {
    guid = 'T1',
    metadata_layers = {
      { key = 'transcript', config = { transcript_file = '/p/linked.json' } },
    },
  }
  return NeedleDiagnosis.new {
    session_id = 'S',
    workflow = {
      audio_tracks = function() return { track } end,
      audio_track = function(_self, _guid) return track end,
    },
    matcher = {
      probe_transcript_file = function(_self, needle, filepath)
        table.insert(probe_calls, { needle = needle, filepath = filepath })
        return probe_results[filepath]
      end,
    },
    folder_scan = {
      scan = function()
        return { transcripts = scan_transcripts, spreadsheets = {} }
      end,
    },
  }
end

TestNeedleDiagnosis = {}

function TestNeedleDiagnosis:setUp()
  stores = {}
  probe_results = {}
  probe_calls = {}
end

-- Transcripts already linked to tracks are not candidates
function TestNeedleDiagnosis:testCandidatesExcludeLinkedTranscripts()
  local diagnosis = make_diagnosis({ '/p/linked.json', '/p/other.json' })
  lu.assertEquals(diagnosis:candidate_files(), { '/p/other.json' })
end

-- An intrinsic non-verbal class explains the empty roll by itself;
-- no evidence pass runs
function TestNeedleDiagnosis:testNonVerbalVerdictSkipsProbes()
  local diagnosis = make_diagnosis({ '/p/other.json' })
  local verdict = diagnosis:diagnose({
    locator = 'L1',
    matchability = { class = 'non_verbal', reason = 'Non-verbal direction' },
  })

  lu.assertEquals(verdict.class, 'non_verbal')
  lu.assertEquals(#probe_calls, 0)
  lu.assertEquals(diagnosis:get('L1').class, 'non_verbal')
end

function TestNeedleDiagnosis:testHitInUnlinkedTranscript()
  probe_results['/p/other.json'] = { confidence = 0.91 }
  local diagnosis = make_diagnosis({ '/p/linked.json', '/p/other.json' })

  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  lu.assertEquals(verdict.class, 'unlinked_track')
  lu.assertStrContains(verdict.reason, 'other.json')
  lu.assertEquals(verdict.evidence.transcript_file, '/p/other.json')
  lu.assertEquals(verdict.evidence.confidence, 0.91)
end

-- The best hit across all candidates names the file
function TestNeedleDiagnosis:testBestHitWins()
  probe_results['/p/weak.json'] = { confidence = 0.4, long_shot = true }
  probe_results['/p/strong.json'] = { confidence = 0.95 }
  local diagnosis = make_diagnosis({ '/p/weak.json', '/p/strong.json' })

  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  lu.assertEquals(verdict.evidence.transcript_file, '/p/strong.json')
end

function TestNeedleDiagnosis:testMissEverywhereIsNotRecorded()
  local diagnosis = make_diagnosis({ '/p/other.json' })

  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  lu.assertEquals(verdict.class, 'not_recorded')
  lu.assertEquals(diagnosis:get('L1').class, 'not_recorded')
end

function TestNeedleDiagnosis:testClearRemovesVerdict()
  local diagnosis = make_diagnosis({})
  diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  diagnosis:clear('L1')

  lu.assertNil(diagnosis:get('L1'))
end

-- refresh_candidates picks up newly linked tracks on the next roll
function TestNeedleDiagnosis:testRefreshRecomputesCandidates()
  local diagnosis = make_diagnosis({ '/p/other.json' })
  lu.assertEquals(#diagnosis:candidate_files(), 1)

  diagnosis.workflow.audio_track = function()
    return {
      metadata_layers = {
        { key = 'transcript', config = { transcript_file = '/p/other.json' } },
      },
    }
  end

  -- Cached until refreshed
  lu.assertEquals(#diagnosis:candidate_files(), 1)
  diagnosis:refresh_candidates()
  lu.assertEquals(#diagnosis:candidate_files(), 0)
end

--

os.exit(lu.LuaUnit.run())
