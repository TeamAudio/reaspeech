
ScriptMaterialExcelSpreadsheet = Polo {
  key = 'excel_spreadsheet',
}

-- What the backend parse endpoint accepts
ScriptMaterialExcelSpreadsheet.BACKEND_EXTENSIONS = {
  ['.xls'] = 'Excel Spreadsheet',
  ['.xlsx'] = 'Excel Spreadsheet',
}

-- What the reaper-datasource extension parses natively
ScriptMaterialExcelSpreadsheet.NATIVE_EXTENSIONS = {
  ['.xls'] = 'Excel Spreadsheet',
  ['.xlsx'] = 'Excel Spreadsheet',
  ['.xlsm'] = 'Excel Spreadsheet',
  ['.xlsb'] = 'Excel Spreadsheet',
  ['.ods'] = 'OpenDocument Spreadsheet',
  ['.csv'] = 'CSV/TSV',
  ['.tsv'] = 'CSV/TSV',
}

-- Import gating is capability-conditional: the native parser opens up
-- formats the backend can't take, and both paths produce the same
-- response shape, so the wider list needs no other changes
function ScriptMaterialExcelSpreadsheet.get_supported_extensions()
  if reaper.DataSource_Parse then
    return ScriptMaterialExcelSpreadsheet.NATIVE_EXTENSIONS
  end
  return ScriptMaterialExcelSpreadsheet.BACKEND_EXTENSIONS
end

function ScriptMaterialExcelSpreadsheet:init()
  Logging().init(self, 'ScriptMaterialExcelSpreadsheet')

  assert(self.session_id, 'ScriptMaterialExcelSpreadsheet: session_id is required')
  assert(self.config, 'ScriptMaterialExcelSpreadsheet: config is required')

  self:log("Initialized ScriptMaterialExcelSpreadsheet")
end

function ScriptMaterialExcelSpreadsheet:can_handle_file(file_path)
  local ext = file_path:match('%.([^%.]+)$')
  if not ext then return false end
  return self.get_supported_extensions()['.' .. ext:lower()] ~= nil
end

function ScriptMaterialExcelSpreadsheet:get_default_material_data()
  return {
    spreadsheet_specific_data = 'neat'
  }
end

-- Sheet config fields the backend parse owns; everything else in a
-- sheet's config is the user's (enabled, layers, line finder, ...)
ScriptMaterialExcelSpreadsheet.PARSE_DERIVED_KEYS = {
  'column_count', 'row_count', 'hidden_rows', 'bold_rows'
}

-- The user-owned sheet config fields, as opposed to parse-derived ones;
-- what propagation and clipboard sharing move around. 'enabled' stays
-- per-sheet: which sheets participate is a selection, not configuration.
ScriptMaterialExcelSpreadsheet.USER_CONFIG_KEYS = {
  'has_header_row', 'skip_hidden_rows', 'line_column', 'line_filters', 'metadata_layers'
}

-- The highest column index the config references; sheets with fewer
-- columns can't hold this config
function ScriptMaterialExcelSpreadsheet.max_referenced_column(config)
  local max_column = config.line_column or 1

  for _, filter in ipairs(config.line_filters or {}) do
    max_column = math.max(max_column, filter.column or 1)
  end
  for _, layer in ipairs(config.metadata_layers or {}) do
    max_column = math.max(max_column, (layer.config and layer.config.column_number) or 1)
  end

  return max_column
end

-- Copy the source sheet's user configuration onto every other sheet in
-- the workbook (deep copies - no shared tables). Sheets without enough
-- columns for the config's references are left alone and reported.
-- Returns the applied and skipped sheet-name lists.
function ScriptMaterialExcelSpreadsheet.propagate_worksheet_config(source_sheet, worksheets)
  local required_columns = ScriptMaterialExcelSpreadsheet.max_referenced_column(source_sheet.config)
  local applied, skipped = {}, {}

  for _, sheet in ipairs(worksheets) do
    if sheet ~= source_sheet and sheet.config then
      local name = sheet.config.name or '?'
      if (sheet.config.column_count or 0) >= required_columns then
        for _, key in ipairs(ScriptMaterialExcelSpreadsheet.USER_CONFIG_KEYS) do
          sheet.config[key] = table.deep_copy(source_sheet.config[key])
        end
        table.insert(applied, name)
      else
        table.insert(skipped, name)
      end
    end
  end

  return applied, skipped
end

ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_PREFIX = 'RSWC:'
ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_KIND = 'reaspeech.worksheet_config'
ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_VERSION = 1

-- A sheet's user configuration as a shareable clipboard blob:
-- version-stamped JSON, base64-wrapped, with a recognizable prefix
function ScriptMaterialExcelSpreadsheet.export_config_blob(sheet)
  local payload = {
    kind = ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_KIND,
    version = ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_VERSION,
    column_count = sheet.config.column_count,
    config = {},
  }

  for _, key in ipairs(ScriptMaterialExcelSpreadsheet.USER_CONFIG_KEYS) do
    payload.config[key] = sheet.config[key]
  end

  return ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_PREFIX
    .. json.encode(payload):base64_encode()
end

-- Validate and apply a clipboard blob to the target sheet. Returns
-- ok, message; nothing is touched unless every check passes.
function ScriptMaterialExcelSpreadsheet.import_config_blob(blob, target_sheet)
  if type(blob) ~= 'string' or blob == '' then
    return false, 'Clipboard is empty'
  end

  blob = blob:match('^%s*(.-)%s*$')
  local prefix = ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_PREFIX
  if blob:sub(1, #prefix) ~= prefix then
    return false, 'Clipboard does not hold a ReaSpeech sheet config'
  end

  local decoded = blob:sub(#prefix + 1):base64_decode()
  if not decoded then
    return false, 'Config blob is damaged (bad base64)'
  end

  local ok, payload = pcall(json.decode, decoded)
  if not ok or type(payload) ~= 'table'
    or payload.kind ~= ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_KIND
    or type(payload.config) ~= 'table'
  then
    return false, 'Config blob is damaged (bad payload)'
  end

  if (payload.version or 0) > ScriptMaterialExcelSpreadsheet.CONFIG_BLOB_VERSION then
    return false, ('Config blob is from a newer ReaSpeech (v%s)'):format(payload.version)
  end

  local required = ScriptMaterialExcelSpreadsheet.max_referenced_column(payload.config)
  local available = (target_sheet.config and target_sheet.config.column_count) or 0
  if available < required then
    return false, ('Config references column %d; this sheet has %d columns'):format(required, available)
  end

  for _, key in ipairs(ScriptMaterialExcelSpreadsheet.USER_CONFIG_KEYS) do
    target_sheet.config[key] = table.deep_copy(payload.config[key])
  end

  return true, 'Config pasted'
end

-- Re-parse support: carry each sheet's user configuration over to the
-- freshly parsed sheets by name, refreshing only the parse-derived
-- fields. Sheets that vanished from the workbook drop away; new sheets
-- arrive with bare parse config. Mutates and returns fresh_worksheets.
function ScriptMaterialExcelSpreadsheet.merge_worksheet_configs(previous_worksheets, fresh_worksheets)
  local previous_by_name = {}
  for _, sheet in ipairs(previous_worksheets or {}) do
    if sheet.config and sheet.config.name then
      previous_by_name[sheet.config.name] = sheet.config
    end
  end

  for _, sheet in ipairs(fresh_worksheets) do
    local previous = sheet.config and previous_by_name[sheet.config.name]
    if previous then
      local fresh_config = sheet.config
      sheet.config = previous
      for _, key in ipairs(ScriptMaterialExcelSpreadsheet.PARSE_DERIVED_KEYS) do
        sheet.config[key] = fresh_config[key]
      end
    end
  end

  return fresh_worksheets
end

function ScriptMaterialExcelSpreadsheet:needles()
  local needles = {}

  for worksheet_index, worksheet in ipairs(self.config.worksheets) do
    local config = worksheet.config or {}

    if config.enabled then
      local line_finder = LineFinder.new {
        has_header_row = config.has_header_row,
        line_filters = config.line_filters or {},
        rows = worksheet.data,
        hidden_rows = config.hidden_rows or {},
        skip_hidden_rows = config.skip_hidden_rows,
      }

      for row_number, row in line_finder:find_lines() do
        local needle = {
          locator = ('worksheet_%d:row_%d'):format(worksheet_index, row_number),
          navigation = { worksheet.config.name },
          content = row[worksheet.config.line_column or 1],
          metadata = self:get_needle_metadata(worksheet, row),
        }
        table.insert(needles, needle)
      end
    end
  end

  return needles
end

function ScriptMaterialExcelSpreadsheet:get_needle_metadata(worksheet, row)
  local metadata = {}

  for _, layer in ipairs(worksheet.config.metadata_layers or {}) do
    local value = self:get_metadata_value(layer, row)
    if value then
      for _, item in ipairs(value) do
        table.insert(metadata, {
          type = layer.key,
          tag = item.tag,
          value = item.value,
        })
      end
    end
  end

  return metadata
end

function ScriptMaterialExcelSpreadsheet:get_metadata_value(layer, row)
  local config = layer.config or {}

  local metadata = {}

  if layer.key == TagsMetadataLayer.key then
    -- Match what the config UI displays: an untouched From Column
    -- combo shows column 1, but only user *changes* used to write
    -- config - so a tag row left at its default column configured
    -- fine on screen and extracted nothing here
    local column_number = config.column_number or 1

    local value = config.tag_value and config.tag_value ~= '' and config.tag_value or row[column_number]
    local tag = config.predefined_tag ~= 'custom' and config.predefined_tag or config.custom_tag

    if tag and tag ~= '' and value and value ~= '' then
      table.insert(metadata, {
        tag = tag,
        value = value,
      })
    end
  end

  return metadata
end