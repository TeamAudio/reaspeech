
ScriptMatchAudioTracks = Polo {}

function ScriptMatchAudioTracks:init()
  Logging().init(self, 'ScriptMatchAudioTracks')

  assert(self.session_id, 'ScriptMatchAudioTracks: session_id is required')

  self.storage = self:get_storage()

  self.audio_tracks = self.storage:table('audio_tracks', {})
end

function ScriptMatchAudioTracks:session_storage_location()
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function ScriptMatchAudioTracks:get_storage()
  local json_file = self:session_storage_location() .. '/audio_tracks.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  })
end

function ScriptMatchAudioTracks:track_storage_location(track_guid)
  assert(track_guid, 'ScriptMatchAudioTracks:track_storage_location: track_guid is required')

  return ('%s/audio_tracks/%s.json'):format(self:session_storage_location(), track_guid)
end

function ScriptMatchAudioTracks:get_track_storage(track_guid)
  assert(track_guid, 'ScriptMatchAudioTracks:get_track_storage: track_guid is required')

  local storage_location = self:track_storage_location(track_guid)

  return Storage.ProjectJSON(storage_location, {
    schema_version = 1,
    migrations = {}
  }):table('track_config', {})
end

function ScriptMatchAudioTracks:get_tracks()
  return self.audio_tracks:get()
end

function ScriptMatchAudioTracks:get_track_by_guid(track_guid)
  assert(track_guid, 'ScriptMatchAudioTracks:get_track_by_guid: track_guid is required')

  local tracks = self.audio_tracks:get()

  for _, track in ipairs(tracks) do
    if track.guid == track_guid then
      return self:get_track_storage(track.guid):get()
    end
  end

  return nil
end

function ScriptMatchAudioTracks:is_track_linked(track_guid)
  assert(track_guid, 'ScriptMatchAudioTracks:is_track_linked: track_guid is required')

  local tracks = self.audio_tracks:get()

  for _, track in ipairs(tracks) do
    if track.guid == track_guid then
      return true
    end
  end

  return false
end

function ScriptMatchAudioTracks:create_track(track)
  assert(track, 'ScriptMatchAudioTracks:create_track: track is required')

  local track_guid = track.guid

  local track_storage = self:get_track_storage(track_guid)
  local track_data = {
    guid = track_guid,
    name = track.name or 'New Audio Track',
    created_at = os.time()
  }
  track_storage:set(track_data)

  self:log("Created audio track: " .. track_guid)

  return track_data
end

function ScriptMatchAudioTracks:add_track(track)
  assert(track, 'ScriptMatchAudioTracks:add_track: track is required')

  local tracks = self.audio_tracks:get()

  for _, existing_track in ipairs(tracks) do
    if existing_track.guid == track.guid then
      self:log("Track already exists: " .. track.name)
      return
    end
  end

  table.insert(tracks, track)
  self.audio_tracks:set(tracks)

  self:log("Added audio track: " .. track.name)
end

function ScriptMatchAudioTracks:unlink_track(track)
  assert(track, 'ScriptMatchAudioTracks:unlink_track: track is required')

  local tracks = self.audio_tracks:get()

  for i, t in ipairs(tracks) do
    if t.guid == track.guid then
      table.remove(tracks, i)
      self.audio_tracks:set(tracks)
      self:log("Unlinked audio track: " .. track.name)
      return true
    end
  end

  self:log("Track not found for unlinking: " .. track.name)
  return false
end

function ScriptMatchAudioTracks:get_project_tracks()
  local tracks = {}

  for track in ReaIter.each_track(ReaperConstants.CURRENT_PROJECT) do
    local track_name_result, track_name = reaper.GetTrackName(track)
    if not track_name_result then
      track_name = 'Track ' .. reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    end

    local track_guid = reaper.GetTrackGUID(track)

    table.insert(tracks, {
      guid = track_guid,
      name = track_name,
      storage_location = self:track_storage_location(track_guid)
    })
  end

  return tracks
end