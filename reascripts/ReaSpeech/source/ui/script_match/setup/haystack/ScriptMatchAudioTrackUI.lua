
ScriptMatchAudioTrackUI = Polo {}

function ScriptMatchAudioTrackUI:init()
  Logging().init(self, 'ScriptMatchAudioTrackUI')

  assert(self.session_id, 'ScriptMatchAudioTrackUI: session_id is required')
  assert(self.workflow, 'ScriptMatchAudioTrackUI: workflow is required')
  assert(self.track, 'ScriptMatchAudioTrackUI: track is required')
  assert(self.audio_tracks, 'ScriptMatchAudioTrackUI: audio_tracks is required')

  self.track_config = self.audio_tracks:get_track_storage(self.track.guid)
  self.is_linked_to_session = self.audio_tracks:is_track_linked(self.track.guid)

  self:log("Initialized ScriptMatchAudioTrackUI")

  self.workflow:listen_for_event('audio_track_metadata_layer_updated', function(event_data)
    local track = event_data.track

    if track and track.guid == self.track.guid then
      local layer = event_data.layer
      self:debug(dump(layer))
      self:log("Metadata layer updated for track: " .. (self.track.name or "<no track name>") .. ", layer: " .. (layer.name or "<no layer name>"))
      self:mark_dirty()
    end
  end)

  self.workflow:listen_for_event('audio_track_metadata_layer_removed', function(event_data)
    local track = event_data.track

    if track and track.guid == self.track.guid then
      local layer = event_data.layer
      self:log("Metadata layer removed for track: " .. (self.track.name or "<no track name>") .. ", layer: " .. (layer.name or "<no layer name>"))
      self:mark_dirty()
    end
  end)
end

function ScriptMatchAudioTrackUI:mark_dirty()
  self:log("Marking track as dirty for track: " .. (self.track.name or "<no track name>"))
  self._dirty_flag = true
end

function ScriptMatchAudioTrackUI:save_if_dirty()
  -- self:log("Save if dirty:" .. tostring(self._dirty_flag) .. ' for track: ' .. (self.track.name or "<no track name>"))
  if not self._dirty_flag then
    return
  end

  self:log("Saving track configuration for track: " .. (self.track.name or "<no track name>"))
  if self.track_configuration_ui then
    self.track.metadata_layers = self.track_configuration_ui:get_metadata_layers()
  end
  self.track_config:set(self.track)
  self.is_linked_to_session = self.audio_tracks:is_track_linked(self.track.guid)
  self._dirty_flag = false
end

function ScriptMatchAudioTrackUI:track_name()
  return self.track.name
end

function ScriptMatchAudioTrackUI:render()
  ImGui.Text(Ctx(), self.track.name)
end

function ScriptMatchAudioTrackUI:render_summary()
  self:render_track_name()

  if self.track_configuration_ui then
    self.track_configuration_ui:render()
  end

  self:save_if_dirty()
end

-- A pressable row per track (chips over small text links): the whole
-- row opens the configuration dialog, unlink keeps its own hit zone
function ScriptMatchAudioTrackUI:render_track_name()
  RowChip.render('##track-row-' .. self.track.guid, {
    icon = 'headphone',
    label = self:track_name(),
    dim = not self.is_linked_to_session,
    tooltip = self.is_linked_to_session
      and 'Linked to this session. Press to configure.'
      or 'Press to link this track to the session and configure it.',
    on_press = function()
      self.track_configuration_ui = ScriptMatchAudioTrackConfigurationUI.new {
        session_id = self.session_id,
        workflow = self.workflow,
        audio_tracks = self.audio_tracks,
        track = self.track,
        track_ui = self,
      }

      self.audio_tracks:add_track(self.track)
      self.is_linked_to_session = true
      self.track_configuration_ui:present()
    end,
    action = self.is_linked_to_session and {
      icon = Icons.x_mark,
      tooltip = 'Unlink this track from the session',
      on_press = function()
        self:log('Unlinking track: ' .. self:track_name())
        self:unlink_track()
      end,
    } or nil,
  })
end

function ScriptMatchAudioTrackUI:unlink_track()
  self:log('Unlinking track: ' .. self.track.name)
  self.audio_tracks:unlink_track(self.track)
  self.is_linked_to_session = false
end

