--[[

  NeedleDiagnosis.lua - evidence-based verdicts for unmatched needles

  A rolled-but-empty needle deserves a WHY, not a silent red badge.
  Intrinsic classes explain themselves (a non-verbal direction can't
  text-match); for the rest, the evidence pass probes every transcript
  discovered in the project folder that no linked track uses. A hit
  names the file the audio actually lives in ("found only on an
  unlinked track" - link it and re-roll); a miss everywhere is strong
  evidence the line was never recorded, which frees it from the
  completion denominator.

  Verdicts persist keyed by LOCATOR (stable across needle
  regeneration, unlike guids) in the session's diagnoses store. A
  later roll that finds suggestions outdates the verdict; the runner
  clears it.

]]--

NeedleDiagnosis = Polo {}

function NeedleDiagnosis:init()
  Logging().init(self, 'NeedleDiagnosis')

  assert(self.session_id, 'NeedleDiagnosis: session_id is required')
  assert(self.workflow, 'NeedleDiagnosis: workflow is required')
  assert(self.matcher, 'NeedleDiagnosis: matcher is required')

  self.storage = Storage.ProjectJSON(
    ('reaspeech/script_match/sessions/%s/diagnoses.json'):format(self.session_id),
    { schema_version = 1, migrations = {} }
  ):table('diagnoses', {})

  self:log('Initialized NeedleDiagnosis')
end

-- Transcript files discovered in the project folder that no linked
-- track uses. Cached until refresh_candidates (a GO run refreshes:
-- tracks may have been linked since). folder_scan injectable for
-- tests.
function NeedleDiagnosis:candidate_files()
  if self._candidates then return self._candidates end

  local linked = {}
  for _, audio_track in ipairs(self.workflow:audio_tracks()) do
    local track = self.workflow:audio_track(audio_track.guid)
    for _, layer in ipairs((track and track.metadata_layers) or {}) do
      if layer.key == TranscriptMetadataLayer.key
        and layer.config and layer.config.transcript_file then
        linked[layer.config.transcript_file] = true
      end
    end
  end

  self._candidates = {}
  local scan = (self.folder_scan or ProjectFolderScan.new {}):scan()
  for _, filepath in ipairs(scan.transcripts) do
    if not linked[filepath] then
      table.insert(self._candidates, filepath)
    end
  end

  self:log(('Diagnosis candidates: %d unlinked transcript(s)'):format(#self._candidates))
  return self._candidates
end

function NeedleDiagnosis:refresh_candidates()
  self._candidates = nil
end

-- Produce and persist the verdict for a rolled-but-empty needle
function NeedleDiagnosis:diagnose(needle)
  local verdict

  local intrinsic = needle.matchability
  if intrinsic and intrinsic.class == 'non_verbal' then
    verdict = { class = 'non_verbal', reason = intrinsic.reason }
  else
    local best_file, best_hit
    for _, filepath in ipairs(self:candidate_files()) do
      local ok, hit = pcall(self.matcher.probe_transcript_file, self.matcher, needle, filepath)
      if not ok then
        self:log('Probe failed for ' .. filepath .. ': ' .. tostring(hit))
      elseif hit and (not best_hit or hit.confidence > best_hit.confidence) then
        best_file, best_hit = filepath, hit
      end
    end

    if best_hit then
      verdict = {
        class = 'unlinked_track',
        reason = ('Found in %s, which is not linked to a track')
          :format(PathUtil.get_filename(best_file)),
        evidence = {
          transcript_file = best_file,
          confidence = best_hit.confidence,
          long_shot = best_hit.long_shot,
        },
      }
      self:attach_track_match(verdict.evidence)
    else
      verdict = {
        class = 'not_recorded',
        reason = 'Not found in any project transcript; likely never recorded',
      }
    end
  end

  verdict.diagnosed_at = os.time()
  self:set(needle.locator, verdict)
  self:log(('Diagnosed %s: %s'):format(tostring(needle.locator), verdict.class))
  return verdict
end

-- When a project track's name matches the transcript's file stem
-- ("VO Quill.json" -> track "VO Quill"), the verdict carries
-- the track so the UI can offer one-press link-and-re-roll. Computed
-- at diagnose time, not render time (no per-frame track enumeration).
function NeedleDiagnosis:attach_track_match(evidence)
  if not self.workflow.get_audio_tracks_service then return end

  local stem = PathUtil.get_filename(evidence.transcript_file):gsub('%.[^%.]+$', '')
  local stem_lower = stem:lower()

  for _, track in ipairs(self.workflow:get_audio_tracks_service():get_project_tracks()) do
    if (track.name or ''):lower() == stem_lower then
      evidence.track_guid = track.guid
      evidence.track_name = track.name
      return
    end
  end
end

-- One-press follow-through on an unlinked_track verdict: link the
-- name-matched project track with the evidence transcript, preserving
-- any configuration the track already has from an earlier linking.
-- Returns ok, message.
function NeedleDiagnosis:link_evidence_track(verdict)
  local evidence = verdict and verdict.evidence
  if not evidence or not evidence.track_guid then
    return false, 'No matching project track to link'
  end

  local service = self.workflow:get_audio_tracks_service()
  local storage = service:get_track_storage(evidence.track_guid)

  local track_data = storage:get()
  if not track_data or not track_data.guid then
    track_data = service:create_track({
      guid = evidence.track_guid,
      name = evidence.track_name,
    })
  end

  track_data.metadata_layers = track_data.metadata_layers or {}
  local transcript_layer
  for _, layer in ipairs(track_data.metadata_layers) do
    if layer.key == TranscriptMetadataLayer.key then
      transcript_layer = layer
    end
  end
  if not transcript_layer then
    transcript_layer = {
      key = TranscriptMetadataLayer.key,
      name = TranscriptMetadataLayer.name,
      config = {},
    }
    table.insert(track_data.metadata_layers, transcript_layer)
  end
  transcript_layer.config = transcript_layer.config or {}
  transcript_layer.config.transcript_file =
    transcript_layer.config.transcript_file or evidence.transcript_file

  storage:set(track_data)
  service:add_track({ guid = track_data.guid, name = track_data.name })

  self.workflow:emit_event('audio_track_metadata_layer_updated', {
    track = track_data,
    layer = transcript_layer,
  })

  -- The linked transcript is no longer diagnosis material
  self:refresh_candidates()

  self:log(('Linked track %s with %s'):format(
    tostring(evidence.track_name), evidence.transcript_file))
  return true, ('Linked %s'):format(evidence.track_name)
end

function NeedleDiagnosis:get(locator)
  if not locator then return nil end
  return self.storage:get()[locator]
end

function NeedleDiagnosis:set(locator, verdict)
  if not locator then return end
  local diagnoses = self.storage:get()
  diagnoses[locator] = verdict
  self.storage:set(diagnoses)
end

-- A roll that FOUND something outdates any earlier verdict
function NeedleDiagnosis:clear(locator)
  if not locator then return end
  local diagnoses = self.storage:get()
  if diagnoses[locator] ~= nil then
    diagnoses[locator] = nil
    self.storage:set(diagnoses)
  end
end
