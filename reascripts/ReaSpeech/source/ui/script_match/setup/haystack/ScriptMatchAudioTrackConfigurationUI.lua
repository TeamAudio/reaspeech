
ScriptMatchAudioTrackConfigurationUI = Polo {}

function ScriptMatchAudioTrackConfigurationUI:init()
  Logging().init(self, 'ScriptMatchAudioTrackConfigurationUI')

  assert(self.session_id, 'ScriptMatchAudioTrackConfigurationUI: session_id is required')
  assert(self.workflow, 'ScriptMatchAudioTrackConfigurationUI: workflow is required')
  assert(self.track, 'ScriptMatchAudioTrackConfigurationUI: track is required')
  assert(self.audio_tracks, 'ScriptMatchAudioTrackConfigurationUI: audio_tracks is required')
  assert(self.track_ui, 'ScriptMatchAudioTrackConfigurationUI: track_ui is required')

  ToolWindow.init(self, {
    title = 'Audio Track Configuration',
    width = 900,
    height = 600,
    window_flags = ImGui.WindowFlags_None() | ImGui.WindowFlags_NoCollapse() | ImGui.WindowFlags_NoDocking(),
  })

  self.track_config = self.audio_tracks:get_track_storage(self.track.guid)

  self.metadata_layers = MetadataLayers.new {
  }

  self.metadata_layer_uis = self:init_metadata_layer_uis()

  -- Fresh per dialog open: transcript JSONs found in the project
  -- folder, offered as one-press links in the Transcript section
  self._project_transcripts = ProjectFolderScan.new {}:scan().transcripts

  -- self:log("Initialized ScriptMatchAudioTrackConfigurationUI")
  self:log("Initialized ScriptMatchAudioTrackConfigurationUI for track: " .. dump(self.track))
end

function ScriptMatchAudioTrackConfigurationUI:get_metadata_layers()
  local metadata_layers = {}

  for _, layer_ui in ipairs(self.metadata_layer_uis) do
    table.insert(metadata_layers, layer_ui.layer)
  end

  return metadata_layers
end

function ScriptMatchAudioTrackConfigurationUI:init_metadata_layer_uis()
  local uis = {}
  for _, layer in ipairs(self.track_config:get().metadata_layers or {}) do
    self:log("Initializing metadata layer UI for layer: " .. dump(layer))
    local layer_ui = ScriptMatchAudioTrackMetadataLayerUI.new {
      session_id = self.session_id,
      workflow = self.workflow,
      layer = layer,
      track = self.track,
      track_configuration_ui = self,
    }
    table.insert(uis, layer_ui)
  end

  return uis
end

function ScriptMatchAudioTrackConfigurationUI:init_new_track(track)
  local track_data = self.audio_tracks:create_track(track)

  self.audio_tracks:add_track(track_data)

  local track_ui = ScriptMatchAudioTrackUI.new {
    session_id = self.session_id,
    track = track_data,
    audio_tracks = self.audio_tracks,
  }

  return track_ui
end

function ScriptMatchAudioTrackConfigurationUI:render_content()
  Fonts.wrap(Ctx(), Fonts.bigboi, function()
    ImGui.Text(Ctx(), self.track.name)
  end, Trap)
  ImGui.Dummy(Ctx(), 0, 4)

  -- Layers are an implementation detail; the dialog speaks the sound
  -- designer's model: a track can have a transcript linked to it, and
  -- carries contextual tags
  self:render_transcript_section()
  ImGui.Dummy(Ctx(), 0, 10)
  self:render_tags_section()
end

function ScriptMatchAudioTrackConfigurationUI:render_section_header(title)
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), title)
  end, Trap)
  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)
end

function ScriptMatchAudioTrackConfigurationUI:layer_uis_for_key(key)
  local uis = {}

  for _, layer_ui in ipairs(self.metadata_layer_uis or {}) do
    if layer_ui.layer.key == key then
      table.insert(uis, layer_ui)
    end
  end

  return uis
end

function ScriptMatchAudioTrackConfigurationUI:registry_layer(key)
  for _, layer in ipairs(self.metadata_layers.registry) do
    if layer.key == key then
      return layer
    end
  end
end

-- Single transcript slot: the data model supports several transcript
-- layers per track, but the UI offers {0..1} until a real
-- multi-transcript workflow shows up
function ScriptMatchAudioTrackConfigurationUI:render_transcript_section()
  self:render_section_header("Transcript")

  local transcript_uis = self:layer_uis_for_key('transcript')

  if #transcript_uis == 0 then
    -- Quick choices ahead of the file browser: transcript JSONs the
    -- project folder already holds, one press to link
    if #(self._project_transcripts or {}) > 0 then
      ImGui.TextColored(Ctx(), 0x888888FF, 'Transcripts found in the project folder:')
    end
    for _, filepath in ipairs(self._project_transcripts or {}) do
      local link_this = function()
        self:link_transcript_file(filepath)
      end
      RowChip.render('##quick-transcript-' .. filepath, {
        icon = 'wav',
        label = PathUtil.get_filename(filepath),
        dim = true,
        tooltip = filepath .. '\nPress to link this transcript.',
        on_press = link_this,
        action = {
          icon = Icons.plus,
          tooltip = 'Link this transcript to the track',
          on_press = link_this,
        },
      })
    end

    if ImGui.Button(Ctx(), "Link Transcript...") then
      self:add_metadata_layer(self:registry_layer('transcript'))

      -- Straight into the file dialog: the empty slot's own button is
      -- the fallback if the user cancels
      local new_ui = self.metadata_layer_uis[#self.metadata_layer_uis]
      if new_ui.handler and new_ui.handler.begin_import then
        new_ui.handler:begin_import()
      end
    end
    return
  end

  for _, layer_ui in ipairs(transcript_uis) do
    layer_ui:render()
  end
end

-- The quick-choice path: create the transcript layer and link the
-- chosen file directly, no file dialog. On failure the empty slot
-- stays (its own Choose button is the retry).
function ScriptMatchAudioTrackConfigurationUI:link_transcript_file(filepath)
  self:add_metadata_layer(self:registry_layer('transcript'))

  local new_ui = self.metadata_layer_uis[#self.metadata_layer_uis]
  if new_ui.handler and new_ui.handler.import_file then
    local ok, err = new_ui.handler:import_file(filepath)
    if not ok then
      self:log("Quick-choice transcript link failed: " .. tostring(err))
    end
  end
end

function ScriptMatchAudioTrackConfigurationUI:render_tags_section()
  self:render_section_header("Tags")

  local tag_uis = self:layer_uis_for_key('tags')

  if #tag_uis > 0 then
    AudioTrackTagsMetadataLayerUI.render_grid_header()
    for _, layer_ui in ipairs(tag_uis) do
      layer_ui:render()
    end
  end

  ImGui.Dummy(Ctx(), 0, 2)
  if ImGui.Button(Ctx(), "+ Add Tag") then
    self:add_metadata_layer(self:registry_layer('tags'))
  end
end

function ScriptMatchAudioTrackConfigurationUI:add_metadata_layer(layer)
  local storage = self.audio_tracks:get_track_storage(self.track.guid)

  local track_config = storage:get() or {}

  -- The stored config is what downstream consumers (workflow:audio_track)
  -- receive, so make sure it carries the track's identity.
  track_config.guid = track_config.guid or self.track.guid
  track_config.name = track_config.name or self.track.name

  if not track_config.metadata_layers then
    track_config.metadata_layers = {}
  end

  local new_layer = {
    guid = reaper.genGuid(''),
    key = layer.key,
    created_at = os.time(),
  }

  table.insert(track_config.metadata_layers, new_layer)

  storage:set(track_config)
  -- Update in place: replacing self.track would lose the guid/name that
  -- this UI and its event listeners rely on.
  self.track.metadata_layers = track_config.metadata_layers

  local new_layer_ui = ScriptMatchAudioTrackMetadataLayerUI.new {
    session_id = self.session_id,
    workflow = self.workflow,
    layer = new_layer,
    track = self.track,
    track_configuration_ui = self,
  }
  table.insert(self.metadata_layer_uis, new_layer_ui)
end

function ScriptMatchAudioTrackConfigurationUI:remove_metadata_layer(layer)
  self:log("Removing metadata layer: " .. (layer.name or "<no layer name>") .. " from track: " .. (self.track.name or "<no track name>"))

  local storage = self.audio_tracks:get_track_storage(self.track.guid)

  local track_config = storage:get() or {}

  if not track_config.metadata_layers then
    return
  end

  local preserved_layer_uis = {}
  local preserved_layers = {}

  for _, layer_ui in ipairs(self.metadata_layer_uis) do
    local ui_layer = layer_ui.layer

    if ui_layer.guid ~= layer.guid then
      table.insert(preserved_layer_uis, layer_ui)
      table.insert(preserved_layers, ui_layer)
    else
      self:log("Found matching layer to remove: " .. tostring(ui_layer.key) .. " (GUID " .. tostring(ui_layer.guid) .. ")")
    end
  end

  self.metadata_layer_uis = preserved_layer_uis
  track_config.metadata_layers = preserved_layers
  track_config.guid = track_config.guid or self.track.guid
  track_config.name = track_config.name or self.track.name

  storage:set(track_config)
  self.track.metadata_layers = track_config.metadata_layers

  self.workflow:emit_event('audio_track_metadata_layer_removed', { track = self.track, layer = layer })
end
