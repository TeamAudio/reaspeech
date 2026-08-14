AudioTrackTagsMetadataLayerUI = Polo {}

function AudioTrackTagsMetadataLayerUI:init()
  Logging().init(self, 'AudioTrackTagsMetadataLayerUI')

  assert(self.session_id, 'AudioTrackTagsMetadataLayerUI: session_id is required')
  assert(self.workflow, 'AudioTrackTagsMetadataLayerUI: workflow is required')
  assert(self.layer, 'AudioTrackTagsMetadataLayerUI: layer is required')
  assert(self.track, 'AudioTrackTagsMetadataLayerUI: track is required')
  assert(self.track_configuration_ui, 'AudioTrackTagsMetadataLayerUI: track_configuration_ui is required')

  self:log("Initialized AudioTrackTagsMetadataLayerUI")

  self.instance_guid = reaper.genGuid('')

  self.layer.config = self.layer.config or {}

  self.storage = {
    predefined_tag = Storage.memory(self.layer.config.predefined_tag or ''),
    custom_tag = Storage.memory(self.layer.config.custom_tag or ''),
    tag_value = Storage.memory(self.layer.config.tag_value or ''),
  }

  self.inputs = {
    combo_predefined_tag = self:input_combo_predefined_tag(),
    text_custom_tag = self:input_text_custom_tag(),
    text_tag_value = self:input_text_tag_value(),
  }

  self.column_layout = self:init_column_layout()
end

function AudioTrackTagsMetadataLayerUI:name()
  return TagsMetadataLayer.name
end

function AudioTrackTagsMetadataLayerUI:render()
  self.column_layout:render()
end

-- INPUTS

function AudioTrackTagsMetadataLayerUI:input_combo_predefined_tag()
  local combo_labels = TagsMetadataLayer.PREDEFINED_TAGS
  local combo_values = {}

  for key, _ in pairs(combo_labels) do
    table.insert(combo_values, key)
  end

  return Widgets.Combo.new {
    state = self.storage.predefined_tag,
    label = "",
    -- label = "Predefined Tag",
    width = function() return self:column_width() end,
    -- options = combo_labels,
    items = combo_values,
    item_labels = function()
      return combo_labels
    end,
    on_change = function()
      self.layer.config.predefined_tag = self.storage.predefined_tag:get()
      self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
    end
  }
end

function AudioTrackTagsMetadataLayerUI:input_text_custom_tag()
  return Widgets.TextInput.new {
    state = self.storage.custom_tag,
    hint = "Name",
    width = function() return self:column_width() end,
    on_change = function()
      self.layer.config.custom_tag = self.storage.custom_tag:get()
      self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
    end,
    on_enter = function()
      self.layer.config.custom_tag = self.storage.custom_tag:get()
      self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
    end,
  }
end

function AudioTrackTagsMetadataLayerUI:input_text_tag_value()
  return Widgets.TextInput.new {
    state = self.storage.tag_value,
    hint = "Value",
    width = function() return self:column_width() end,
    on_change = function()
      self.layer.config.tag_value = self.storage.tag_value:get()
      self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
    end,
    on_enter = function()
      self.layer.config.tag_value = self.storage.tag_value:get()
      self.workflow:emit_event('audio_track_metadata_layer_updated', { track = self.track, layer = self.layer })
    end,
  }
end

function AudioTrackTagsMetadataLayerUI:render_remove_tag_button()
  if ImGui.Button(Ctx(), "Remove") then
    self.track_configuration_ui:remove_metadata_layer(self.layer)
  end
end

-- The name input only exists for custom tags; predefined rows keep
-- the slot blank so the grid stays aligned
function AudioTrackTagsMetadataLayerUI:render_custom_tag_column()
  if self.storage.predefined_tag:get() == 'custom' then
    self.inputs.text_custom_tag:render()
  end
end

-- UI INIT

function AudioTrackTagsMetadataLayerUI:column_width()
  return self._column_width
end

AudioTrackTagsMetadataLayerUI.GRID_COLUMNS = 4
AudioTrackTagsMetadataLayerUI.GRID_SPACING = 10
AudioTrackTagsMetadataLayerUI.GRID_LABELS = { 'Tag', 'Custom Name', 'Value', '' }

-- Column labels rendered once above the rows (same layout config as
-- the rows, so the widths line up)
function AudioTrackTagsMetadataLayerUI.render_grid_header()
  if not AudioTrackTagsMetadataLayerUI._header_layout then
    AudioTrackTagsMetadataLayerUI._header_layout = ColumnLayout.new {
      spacing = AudioTrackTagsMetadataLayerUI.GRID_SPACING,
      num_columns = AudioTrackTagsMetadataLayerUI.GRID_COLUMNS,
      render_column = function(column)
        local label = AudioTrackTagsMetadataLayerUI.GRID_LABELS[column.num]
        if label ~= '' then
          ImGui.TextDisabled(Ctx(), label)
        end
      end
    }
  end

  AudioTrackTagsMetadataLayerUI._header_layout:render()
end

function AudioTrackTagsMetadataLayerUI:init_column_layout()
  local columns = {
    self.inputs.combo_predefined_tag,
    { render = function() self:render_custom_tag_column() end },
    self.inputs.text_tag_value,
    { render = function() self:render_remove_tag_button() end },
  }
  return ColumnLayout.new {
    spacing = AudioTrackTagsMetadataLayerUI.GRID_SPACING,
    num_columns = AudioTrackTagsMetadataLayerUI.GRID_COLUMNS,
    render_column = function(column)
      self._column_width = column.width
      if ImGui.BeginChild(Ctx(), 'tag-column-' .. column.num .. self.instance_guid, column.width, 0, ImGui.ChildFlags_AutoResizeY(), ImGui.WindowFlags_None()) then
        Trap(function()
          columns[column.num]:render()
        end)
        ImGui.EndChild(Ctx())
      end
    end
  }
end