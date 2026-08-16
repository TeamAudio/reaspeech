
AudioTrackTranscriptMetadataLayerUI = Polo {}

function AudioTrackTranscriptMetadataLayerUI:init()
  Logging().init(self, 'AudioTrackTranscriptMetadataLayerUI')

  assert(self.session_id, 'AudioTrackTranscriptMetadataLayerUI: session_id is required')
  assert(self.workflow, 'AudioTrackTranscriptMetadataLayerUI: workflow is required')
  assert(self.layer, 'AudioTrackTranscriptMetadataLayerUI: layer is required')
  assert(self.track, 'AudioTrackTranscriptMetadataLayerUI: track is required')
  assert(self.track_configuration_ui, 'AudioTrackTranscriptMetadataLayerUI: track_configuration_ui is required')

  self:log("Initialized AudioTrackTranscriptMetadataLayerUI")

  self.instance_guid = reaper.genGuid('')

  self.layer.config = self.layer.config or {}

  self.storage = {
    transcript_file = Storage.memory(self.layer.config.transcript_file or ''),
  }
end

function AudioTrackTranscriptMetadataLayerUI:name()
  return TranscriptMetadataLayer.name
end

function AudioTrackTranscriptMetadataLayerUI:render()
  -- Scope widget IDs to this layer instance: the same button labels
  -- repeat for every transcript layer in the window.
  ImGui.PushID(Ctx(), self.instance_guid)
  Trap(function()
    self:render_controls()
  end)
  ImGui.PopID(Ctx())
end

-- One line when linked: filename + segment count, full path in the
-- tooltip, Remove anchored to the right edge (measured, so it can't
-- clip). Unlinked: a single button into the file dialog.
function AudioTrackTranscriptMetadataLayerUI:render_controls()
  local transcript = self:get_transcript()

  if not transcript then
    if ImGui.Button(Ctx(), "Choose Transcript File...") then
      self:begin_import()
    end
    return
  end

  ImGui.Text(Ctx(), ("%s - %d segments"):format(
    PathUtil.get_filename(transcript.filepath),
    #transcript:get_segments()))
  ImGui.SetItemTooltip(Ctx(), transcript.filepath)

  ImGui.SameLine(Ctx())
  local avail = ImGui.GetContentRegionAvail(Ctx())
  local pad_x = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_FramePadding())
  local button_width = ImGui.CalcTextSize(Ctx(), "Remove") + pad_x * 2
  ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + math.max(0, avail - button_width))

  if ImGui.Button(Ctx(), "Remove") then
    self.track_configuration_ui:remove_metadata_layer(self.layer)
  end
end

function AudioTrackTranscriptMetadataLayerUI:begin_import()
  TranscriptImporter:quick_import(function(imported, filename)
    self:attach_transcript(imported, filename)
  end)()
end

-- Link a known file directly - the quick-choice path, no file dialog.
-- Returns ok, error message.
function AudioTrackTranscriptMetadataLayerUI:import_file(filename)
  local transcript, err = TranscriptImporter:import(filename)
  if not transcript then
    self:log("Error loading transcript from file: " .. tostring(err))
    return false, err
  end

  self:attach_transcript(transcript, filename)
  return true
end

function AudioTrackTranscriptMetadataLayerUI:attach_transcript(transcript, filename)
  self._transcript = transcript
  self.storage.transcript_file:set(filename)
  self.layer.config.transcript_file = filename
  self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
  self:log("Imported transcript from file: " .. filename)
end

function AudioTrackTranscriptMetadataLayerUI:get_transcript()
  if self._transcript then
    return self._transcript
  end

  local transcript_file = self.storage.transcript_file:get()

  if transcript_file and transcript_file ~= '' then
    local transcript, err = TranscriptImporter:import(transcript_file)
    if transcript then
      self._transcript = transcript
      return transcript
    else
      self:log("Error loading transcript from file: " .. err)
      return nil, err
    end
  end
end
