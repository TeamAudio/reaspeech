ScriptMaterialTagsMetadataLayerUI = Polo {}

function ScriptMaterialTagsMetadataLayerUI:init()
  Logging().init(self, 'ScriptMaterialTagsMetadataLayerUI')

  assert(self.session_id, 'ScriptMaterialTagsMetadataLayerUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialTagsMetadataLayerUI: workflow is required')
  assert(self.layer, 'ScriptMaterialTagsMetadataLayerUI: layer is required')
  assert(self.material, 'ScriptMaterialTagsMetadataLayerUI: material is required')

  self:log("Initialized ScriptMaterialTagsMetadataLayerUI for layer: " .. dump(self.layer))

  self.instance_guid = reaper.genGuid('')

  self.layer.config = self.layer.config or {}

  -- Persist the displayed default: widgets seed their display from
  -- `config value or default`, but only change events write config -
  -- so a row left at the default column LOOKED configured while the
  -- config held nil (and extraction skipped the tag)
  self.layer.config.column_number = self.layer.config.column_number or 1

  self.storage = {
    predefined_tag = Storage.memory(self.layer.config.predefined_tag or ''),
    custom_tag = Storage.memory(self.layer.config.custom_tag or ''),
    column_number = Storage.memory(self.layer.config.column_number or 1),
    tag_value = Storage.memory(self.layer.config.tag_value or ''),
  }

  self.inputs = {
    combo_predefined_tag = self:input_combo_predefined_tag(),
    text_custom_tag = self:input_text_custom_tag(),
    text_tag_value = self:input_text_tag_value(),
    combo_column_number = self:input_combo_column_number(),
  }

  self.column_layout = self:init_column_layout()
end

function ScriptMaterialTagsMetadataLayerUI:name()
  return TagsMetadataLayer.name
end

function ScriptMaterialTagsMetadataLayerUI:render()
  self.column_layout:render()
end

function ScriptMaterialTagsMetadataLayerUI:column_width()
  return self._column_width
end

-- INPUTS

function ScriptMaterialTagsMetadataLayerUI:input_combo_predefined_tag()
  local combo_labels = TagsMetadataLayer.PREDEFINED_TAGS
  local combo_values = {}

  for key, _ in pairs(combo_labels) do
    table.insert(combo_values, key)
  end

  return Widgets.Combo.new {
    state = self.storage.predefined_tag,
    items = combo_values,
    item_labels = combo_labels,
    width = function() return self:column_width() end,
    on_change = function(value)
      -- self.storage.predefined_tag:set(value)
      self.layer.config.predefined_tag = value

      -- Setup assist: a tag with a same-named column snaps to it
      local column = TagsMetadataLayer.find_matching_column(value, self:get_column_labels())
      if column then
        self.layer.config.column_number = column
        self.storage.column_number:set(column)
      end

      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

function ScriptMaterialTagsMetadataLayerUI:input_text_custom_tag()
  return Widgets.TextInput.new {
    state = self.storage.custom_tag,
    hint = "Name",
    width = function() return self:column_width() end,
    on_change = function(value)
      -- self.storage.custom_tag:set(value)
      self.layer.config.custom_tag = value
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

function ScriptMaterialTagsMetadataLayerUI:input_text_tag_value()
  return Widgets.TextInput.new {
    state = self.storage.tag_value,
    hint = "Value",
    width = function() return self:column_width() end,
    on_change = function(value)
      -- self.storage.tag_value:set(value)
      self.layer.config.tag_value = value
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

function ScriptMaterialTagsMetadataLayerUI:column_count()
  local sheet_config = self.sheet_config or self.material
  return sheet_config.column_count or 0
end

function ScriptMaterialTagsMetadataLayerUI:get_column_values()
  local columns = {}
  for i = 1, self:column_count() do
    table.insert(columns, i)
  end
  return columns
end

function ScriptMaterialTagsMetadataLayerUI:get_column_labels()
  -- Provided by the owning worksheet UI, which labels columns with the
  -- header row values when "Has Header Row" is enabled.
  if self.column_labels then
    return self.column_labels()
  end

  local labels = {}
  for i = 1, self:column_count() do
    table.insert(labels, "Column " .. i)
  end
  return labels
end

function ScriptMaterialTagsMetadataLayerUI:input_combo_column_number()
  return Widgets.Combo.new {
    state = self.storage.column_number,
    items = self:get_column_values(),
    item_labels = function() return self:get_column_labels() end,
    width = function() return self:column_width() end,
    on_change = function(value)
      -- self.storage.column_number:set(value)
      self.layer.config.column_number = value
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

-- Actually removes the row: the owning worksheet UI deletes the layer
-- from config and rebuilds (the old behavior only blanked the fields,
-- leaving an orphan layer in config.metadata_layers)
function ScriptMaterialTagsMetadataLayerUI:render_remove_tag_button()
  if ImGui.Button(Ctx(), "Remove") then
    if self.on_remove then
      self.on_remove(self.layer)
    end
  end
end

-- The name input only exists for custom tags; predefined rows keep
-- the slot blank so the grid stays aligned
function ScriptMaterialTagsMetadataLayerUI:render_custom_tag_column()
  if self.storage.predefined_tag:get() == 'custom' then
    self.inputs.text_custom_tag:render()
  end
end

ScriptMaterialTagsMetadataLayerUI.GRID_COLUMNS = 5
ScriptMaterialTagsMetadataLayerUI.GRID_SPACING = 10
ScriptMaterialTagsMetadataLayerUI.GRID_LABELS = { 'Tag', 'Custom Name', 'Value', 'From Column', '' }

-- Column labels rendered once above the rows (same layout config as
-- the rows, so the widths line up)
function ScriptMaterialTagsMetadataLayerUI.render_grid_header()
  if not ScriptMaterialTagsMetadataLayerUI._header_layout then
    ScriptMaterialTagsMetadataLayerUI._header_layout = ColumnLayout.new {
      spacing = ScriptMaterialTagsMetadataLayerUI.GRID_SPACING,
      num_columns = ScriptMaterialTagsMetadataLayerUI.GRID_COLUMNS,
      render_column = function(column)
        local label = ScriptMaterialTagsMetadataLayerUI.GRID_LABELS[column.num]
        if label ~= '' then
          ImGui.TextDisabled(Ctx(), label)
        end
      end
    }
  end

  ScriptMaterialTagsMetadataLayerUI._header_layout:render()
end

function ScriptMaterialTagsMetadataLayerUI:init_column_layout()
  local columns = {
    self.inputs.combo_predefined_tag,
    { render = function() self:render_custom_tag_column() end },
    self.inputs.text_tag_value,
    self.inputs.combo_column_number,
    { render = function() self:render_remove_tag_button() end }
  }

  return ColumnLayout.new {
    spacing = ScriptMaterialTagsMetadataLayerUI.GRID_SPACING,
    num_columns = ScriptMaterialTagsMetadataLayerUI.GRID_COLUMNS,
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