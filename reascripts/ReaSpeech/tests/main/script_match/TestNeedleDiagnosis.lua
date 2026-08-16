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

-- Fake audio-tracks service: project tracks by name, in-memory
-- per-track storage, session link list
local function make_tracks_service(project_tracks)
  local track_stores = {}
  local session_tracks = {}
  return {
    session_tracks = session_tracks,
    track_stores = track_stores,
    get_project_tracks = function() return project_tracks or {} end,
    get_track_storage = function(_self, guid)
      return {
        get = function() return track_stores[guid] end,
        set = function(_s, value) track_stores[guid] = value end,
      }
    end,
    create_track = function(_self, track)
      track_stores[track.guid] = { guid = track.guid, name = track.name }
      return track_stores[track.guid]
    end,
    add_track = function(_self, track) table.insert(session_tracks, track) end,
  }
end

local function make_diagnosis(scan_transcripts, tracks_service)
  local track = {
    guid = 'T1',
    metadata_layers = {
      { key = 'transcript', config = { transcript_file = '/p/linked.json' } },
    },
  }
  local events = {}
  local workflow = {
    events = events,
    audio_tracks = function() return { track } end,
    audio_track = function(_self, _guid) return track end,
    emit_event = function(_self, name, data)
      table.insert(events, { name = name, data = data })
    end,
  }
  if tracks_service then
    workflow.get_audio_tracks_service = function() return tracks_service end
  end
  return NeedleDiagnosis.new {
    session_id = 'S',
    workflow = workflow,
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

-- A project track named like the transcript's file stem rides the
-- evidence, powering the one-press link affordance
function TestNeedleDiagnosis:testEvidenceCarriesNameMatchedTrack()
  probe_results['/p/VO Quill.json'] = { confidence = 0.9 }
  local service = make_tracks_service({ { guid = 'PT1', name = 'VO Quill' } })
  local diagnosis = make_diagnosis({ '/p/VO Quill.json' }, service)

  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  lu.assertEquals(verdict.evidence.track_guid, 'PT1')
  lu.assertEquals(verdict.evidence.track_name, 'VO Quill')
end

function TestNeedleDiagnosis:testNoNameMatchLeavesEvidenceBare()
  probe_results['/p/mystery.json'] = { confidence = 0.9 }
  local service = make_tracks_service({ { guid = 'PT1', name = 'VO Quill' } })
  local diagnosis = make_diagnosis({ '/p/mystery.json' }, service)

  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  lu.assertNil(verdict.evidence.track_guid)
end

function TestNeedleDiagnosis:testLinkEvidenceTrack()
  probe_results['/p/VO Quill.json'] = { confidence = 0.9 }
  local service = make_tracks_service({ { guid = 'PT1', name = 'VO Quill' } })
  local diagnosis = make_diagnosis({ '/p/VO Quill.json' }, service)
  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  local ok, message = diagnosis:link_evidence_track(verdict)

  lu.assertTrue(ok)
  lu.assertStrContains(message, 'VO Quill')

  -- Track storage carries the transcript layer; the session links it
  local stored = service.track_stores['PT1']
  lu.assertEquals(stored.metadata_layers[1].key, 'transcript')
  lu.assertEquals(stored.metadata_layers[1].config.transcript_file, '/p/VO Quill.json')
  lu.assertEquals(service.session_tracks[1].guid, 'PT1')

  -- The workflow heard about it
  local found_event = false
  for _, event in ipairs(diagnosis.workflow.events) do
    if event.name == 'audio_track_metadata_layer_updated' then found_event = true end
  end
  lu.assertTrue(found_event)
end

-- An earlier configuration (tags, a transcript already chosen)
-- survives re-linking
function TestNeedleDiagnosis:testLinkPreservesExistingTrackConfig()
  probe_results['/p/VO Quill.json'] = { confidence = 0.9 }
  local service = make_tracks_service({ { guid = 'PT1', name = 'VO Quill' } })
  service.track_stores['PT1'] = {
    guid = 'PT1', name = 'VO Quill',
    metadata_layers = {
      { key = 'tags', config = { predefined_tag = 'character' } },
    },
  }
  local diagnosis = make_diagnosis({ '/p/VO Quill.json' }, service)
  local verdict = diagnosis:diagnose({ locator = 'L1', content = 'some line' })

  diagnosis:link_evidence_track(verdict)

  local stored = service.track_stores['PT1']
  lu.assertEquals(#stored.metadata_layers, 2)
  lu.assertEquals(stored.metadata_layers[1].key, 'tags')
  lu.assertEquals(stored.metadata_layers[2].config.transcript_file, '/p/VO Quill.json')
end

function TestNeedleDiagnosis:testLinkWithoutTrackMatchRefuses()
  local diagnosis = make_diagnosis({})
  local ok, message = diagnosis:link_evidence_track({
    class = 'unlinked_track', evidence = { transcript_file = '/p/x.json' },
  })
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'No matching')
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
