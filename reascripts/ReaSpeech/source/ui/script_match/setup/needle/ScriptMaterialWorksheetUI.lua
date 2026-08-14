ScriptMaterialWorksheetUI = Polo {}

function ScriptMaterialWorksheetUI:init()
  Logging().init(self, 'ScriptMaterialWorksheetUI')

  assert(self.session_id, 'ScriptMaterialWorksheetUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialWorksheetUI: workflow is required')
  assert(self.material, 'ScriptMaterialWorksheetUI: material is required')
  assert(self.sheet, 'ScriptMaterialWorksheetUI: sheet is required')

  self.instance_guid = reaper.genGuid('')

  self.config = self.sheet.config

  -- Checkbox.new invokes changed_handler at construction (with the
  -- default value); suppress change events until real user edits, or
  -- merely building this UI announces a phantom material change
  self._initializing = true
  self.widgets = self:init_widgets()
  self._initializing = nil

  self:log("Initialized ScriptMaterialWorksheetUI")
end

function ScriptMaterialWorksheetUI:init_widgets()
  local widgets = {
    enabled = self:init_checkbox_enabled(),
    has_header_row = self:init_checkbox_has_header_row(),
    skip_hidden_rows = self:init_checkbox_skip_hidden_rows(),
    line_column = self:init_combo_line_column(),
    line_filters = self:init_line_filters(),
    metadata_layers = self:init_metadata_layers(),
  }

  return widgets
end

function ScriptMaterialWorksheetUI:init_checkbox_enabled()
  return Widgets.Checkbox.new {
    label_long = "Enabled",
    label_short = "Enabled",
    default = self.config.enabled,
    changed_handler = function(value)
      self.config.enabled = value
      if self._initializing then return end
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

function ScriptMaterialWorksheetUI:init_checkbox_has_header_row()
  self:log("has_header_row: " .. dump(self.config.has_header_row))
  return Widgets.Checkbox.new {
    label_long = "Has Header Row",
    label_short = "Has Header Row",
    default = self.config.has_header_row,
    changed_handler = function(value)
      self.config.has_header_row = value
      if self._initializing then return end
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end


function ScriptMaterialWorksheetUI:init_checkbox_skip_hidden_rows()
  return Widgets.Checkbox.new {
    label_long = "Skip Hidden Rows",
    label_short = "Skip Hidden Rows",
    default = self.config.skip_hidden_rows ~= false,
    changed_handler = function(value)
      self.config.skip_hidden_rows = value
      if self._initializing then return end
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

-- The column containing the actual line text: this is what becomes each
-- needle's content (ScriptMaterialExcelSpreadsheet:needles).
function ScriptMaterialWorksheetUI:init_combo_line_column()
  return Widgets.Combo.new {
    default = self.config.line_column or 1,
    items = self:get_column_values(),
    item_labels = function() return self:get_column_labels() end,
    on_change = function(value)
      self.config.line_column = value
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
  }
end

function ScriptMaterialWorksheetUI:init_line_filters()
  local line_filters = self.config.line_filters or {}

  local filter_uis = {}

  for filter_index, filter in ipairs(line_filters) do

    local widgets = {
      column_combo = Widgets.Combo.new {
        default = filter.column,
        items = self:get_column_values(),
        item_labels = function() return self:get_column_labels() end,
        on_change = function(value)
          filter.column = value
          self.workflow:emit_event('script_material_updated', { material = self.material })
        end
      },
      filter_type_combo = Widgets.Combo.new {
        default = filter.type,
        items = LineFinder.FILTER_TYPE_VALUES,
        item_labels = LineFinder.FILTER_TYPE_LABELS,
        on_change = function(value)
          filter.type = value
          self.workflow:emit_event('script_material_updated', { material = self.material })
        end
      },
      filter_value_input = Widgets.TextInput.new {
        default = filter.value,
        disabled = function() return not LineFinder.FILTER_TYPES[filter.type].needs_value end,
        on_change = function(value)
          filter.value = value
          self.workflow:emit_event('script_material_updated', { material = self.material })
        end
      }
    }

    local renderers = {
      widgets.column_combo,
      widgets.filter_type_combo,
      widgets.filter_value_input,
      { render = function()
        if ImGui.Button(Ctx(), "Remove") then
          table.remove(self.config.line_filters, filter_index)
          self.widgets.line_filters = self:init_line_filters()
          self.workflow:emit_event('script_material_updated', { material = self.material })
        end
      end },
    }

    widgets.column_layout = ColumnLayout.new {
      num_columns = ScriptMaterialWorksheetUI.FILTER_GRID_COLUMNS,
      spacing = ScriptMaterialWorksheetUI.FILTER_GRID_SPACING,
      render_column = function(column)
        self._column_width = column.width
        if ImGui.BeginChild(Ctx(), 'filter-' .. filter_index .. '-column-' .. column.num .. self.instance_guid, column.width, 0, ImGui.ChildFlags_AutoResizeY(), ImGui.WindowFlags_None()) then
          Trap(function()
            renderers[column.num]:render()
          end)
          ImGui.EndChild(Ctx())
        end
      end
    }

    table.insert(filter_uis, widgets)
  end

  return filter_uis
end

function ScriptMaterialWorksheetUI:get_column_values()
  local columns = {}
  for i = 1, self.config.column_count do
    table.insert(columns, i)
  end
  return columns
end

function ScriptMaterialWorksheetUI:get_column_labels()
  local header_row = self.config.has_header_row
    and self.sheet.data and self.sheet.data[1]

  local labels = {}
  for i = 1, self.config.column_count do
    local header = header_row and header_row[i]
    if header and header ~= '' then
      table.insert(labels, header)
    else
      table.insert(labels, "Column " .. i)
    end
  end
  return labels
end

function ScriptMaterialWorksheetUI:init_metadata_layers()
  local uis = {}
  for _, layer in ipairs(self.config.metadata_layers or {}) do
    self:log("Initializing metadata layer UI for layer: " .. dump(layer))
    local layer_ui = ScriptMaterialMetadataLayerUI.new {
      session_id = self.session_id,
      workflow = self.workflow,
      layer = layer,
      material = self.material,
      sheet_config = self.config,
      column_labels = function() return self:get_column_labels() end,
      on_remove = function(removed_layer) self:remove_metadata_layer(removed_layer) end,
    }
    table.insert(uis, layer_ui)
  end

  return uis
end

function ScriptMaterialWorksheetUI:remove_metadata_layer(layer)
  for i, existing in ipairs(self.config.metadata_layers or {}) do
    if existing == layer then
      table.remove(self.config.metadata_layers, i)
      break
    end
  end

  self.widgets.metadata_layers = self:init_metadata_layers()
  self.workflow:emit_event('script_material_updated', { material = self.material })
end

function ScriptMaterialWorksheetUI:add_tag_layer()
  local new_layer = {
    key = TagsMetadataLayer.key,
    name = TagsMetadataLayer.name,
    config = {}
  }

  -- Setup assist: preconfigure the first predefined tag that matches a
  -- column header by name and isn't already claimed by another layer
  local claimed = {}
  for _, layer in ipairs(self.config.metadata_layers or {}) do
    if layer.config and layer.config.predefined_tag then
      claimed[layer.config.predefined_tag] = true
    end
  end

  for _, tag_key in ipairs(TagsMetadataLayer.AUTO_MATCH_TAGS) do
    if not claimed[tag_key] then
      local column = TagsMetadataLayer.find_matching_column(tag_key, self:get_column_labels())
      if column then
        new_layer.config.predefined_tag = tag_key
        new_layer.config.column_number = column
        break
      end
    end
  end

  self.config.metadata_layers = self.config.metadata_layers or {}
  table.insert(self.config.metadata_layers, new_layer)

  -- Rebuild rather than append so every row binds on_remove the same way
  self.widgets.metadata_layers = self:init_metadata_layers()
  self.workflow:emit_event('script_material_updated', { material = self.material })
end

ScriptMaterialWorksheetUI.FILTER_GRID_COLUMNS = 4
ScriptMaterialWorksheetUI.FILTER_GRID_SPACING = 10
ScriptMaterialWorksheetUI.FILTER_GRID_LABELS = { 'Column', 'Condition', 'Value', '' }

function ScriptMaterialWorksheetUI:render()
  -- Scope all widget IDs to this worksheet: the same labels (checkboxes,
  -- "+ Add Filter", "+ Add Tag") repeat for every worksheet in the window.
  ImGui.PushID(Ctx(), self.instance_guid)

  self.widgets.enabled:render()
  ImGui.SameLine(Ctx())
  self.widgets.has_header_row:render()
  ImGui.SameLine(Ctx())
  self.widgets.skip_hidden_rows:render()

  ImGui.Dummy(Ctx(), 0, 4)
  ImGui.Text(Ctx(), "Line Column:")
  ImGui.SameLine(Ctx())
  self.widgets.line_column:render()

  ImGui.Dummy(Ctx(), 0, 8)
  self:render_line_finder_section()

  ImGui.Dummy(Ctx(), 0, 8)
  self:render_tags_section()

  ImGui.PopID(Ctx())
end

function ScriptMaterialWorksheetUI:render_section_header(title)
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), title)
  end, Trap)
  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)
end

function ScriptMaterialWorksheetUI:render_line_filter_header()
  if not self._filter_header_layout then
    self._filter_header_layout = ColumnLayout.new {
      spacing = ScriptMaterialWorksheetUI.FILTER_GRID_SPACING,
      num_columns = ScriptMaterialWorksheetUI.FILTER_GRID_COLUMNS,
      render_column = function(column)
        local label = ScriptMaterialWorksheetUI.FILTER_GRID_LABELS[column.num]
        if label ~= '' then
          ImGui.TextDisabled(Ctx(), label)
        end
      end
    }
  end

  self._filter_header_layout:render()
end

function ScriptMaterialWorksheetUI:render_line_finder_section()
  self:render_section_header("Line Finder")

  if #self.widgets.line_filters > 0 then
    self:render_line_filter_header()
  end

  for _, filter_ui in ipairs(self.widgets.line_filters) do
    filter_ui.column_layout:render()
  end

  ImGui.Dummy(Ctx(), 0, 2)
  if ImGui.Button(Ctx(), "+ Add Filter") then
    local new_filter = {
      column = 1,
      type = LineFinder.FILTER_TYPE_VALUES[1],
      value = ''
    }
    if not self.config.line_filters then
      self.config.line_filters = {}
    end
    table.insert(self.config.line_filters, new_filter)
    self.widgets.line_filters = self:init_line_filters()
    self.workflow:emit_event('script_material_updated', { material = self.material })
  end
end

function ScriptMaterialWorksheetUI:render_tags_section()
  self:render_section_header("Tags")

  if #self.widgets.metadata_layers > 0 then
    ScriptMaterialTagsMetadataLayerUI.render_grid_header()
    for _, layer_ui in ipairs(self.widgets.metadata_layers) do
      layer_ui:render()
    end
  end

  ImGui.Dummy(Ctx(), 0, 2)
  if ImGui.Button(Ctx(), "+ Add Tag") then
    self:add_tag_layer()
  end
end