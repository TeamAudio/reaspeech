package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')
require('libs/TableUtils')
require('libs/StringUtils')
require('vendor/json')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

dump = function() return '' end

reaper = {}

-- Worksheet UIs are ImGui-heavy; the parse flow only needs them constructible
ScriptMaterialWorksheetUI = {
  new = function(options)
    return { config = options.sheet.config or {}, sheet = options.sheet }
  end
}

require('main/script_match/metadata_layers/TagsMetadataLayer')
require('main/script_match/setup/needle/LineFinder')
require('main/script_match/setup/needle/ScriptMaterialExcelSpreadsheet')
require('ui/script_match/setup/needle/ScriptMaterialExcelSpreadsheetUI')

--

local WORKBOOK_JSON = json.encode({
  config = { file_type = 'excel', file_name = 'lines.xlsx', sheets = 1 },
  sheets = {
    {
      config = {
        name = 'Alpha',
        column_count = 3,
        row_count = 2,
        hidden_rows = {},
        bold_rows = {},
      },
      data = {
        { 'Filename', 'Character', 'Line' },
        { 'VO_001', 'SOLACE', 'First line' },
      },
    },
  },
})

local function make_ui()
  local recorded = { events = {}, saved = nil }

  local storage = {
    get = function() return { worksheets = {} } end,
    set = function(_, material) recorded.saved = material end,
  }

  local ui = ScriptMaterialExcelSpreadsheetUI.new {
    session_id = 'session-1',
    workflow = {
      listen_for_event = function() end,
      emit_event = function(_, name) table.insert(recorded.events, name) end,
    },
    material = {
      type = ScriptMaterialExcelSpreadsheet.key,
      guid = 'guid-1',
      filepath = '/tmp/lines.xlsx',
      name = 'lines.xlsx',
    },
    materials = {
      get_material_storage = function() return storage end,
    },
  }

  return ui, recorded
end

--

TestNativeParse = {}

function TestNativeParse:test_parses_synchronously_via_datasource()
  local ui, recorded = make_ui()
  local parsed_path
  reaper.DataSource_Parse = function(path, _)
    parsed_path = path
    return true, WORKBOOK_JSON
  end

  ui:parse_spreadsheet()

  lu.assertEquals(parsed_path, '/tmp/lines.xlsx')
  lu.assertEquals(ui.material_config.is_parsed, true)
  lu.assertEquals(#ui.material_config.worksheets, 1)
  lu.assertEquals(ui.material_config.worksheets[1].config.name, 'Alpha')
  lu.assertNil(ui.parse_error)
  lu.assertEquals(recorded.events, { 'script_material_updated' })
  lu.assertEquals(recorded.saved, ui.material_config)
end

function TestNativeParse:test_parse_failure_sets_error_without_retry_loop()
  local ui, recorded = make_ui()
  reaper.DataSource_Parse = function()
    return false, 'file_path does not name a readable file'
  end

  ui:parse_spreadsheet()

  lu.assertEquals(ui.parse_error, 'file_path does not name a readable file')
  lu.assertNotEquals(ui.material_config.is_parsed, true)
  lu.assertEquals(recorded.events, {})
end

function TestNativeParse:test_undecodable_output_sets_error()
  local ui = make_ui()
  reaper.DataSource_Parse = function()
    return true, 'not json at all'
  end

  ui:parse_spreadsheet()

  lu.assertStrContains(ui.parse_error, 'Could not decode parser output')
end

function TestNativeParse:test_retry_clears_previous_error()
  local ui = make_ui()
  reaper.DataSource_Parse = function()
    return false, 'transient'
  end
  ui:parse_spreadsheet()
  lu.assertEquals(ui.parse_error, 'transient')

  reaper.DataSource_Parse = function()
    return true, WORKBOOK_JSON
  end
  ui:parse_spreadsheet()
  lu.assertNil(ui.parse_error)
  lu.assertEquals(ui.material_config.is_parsed, true)
end

TestMissingExtension = {}

-- Without reaper-datasource there is no parser at all: the material
-- shows an install message with Retry and nothing is stored or emitted
function TestMissingExtension:test_reports_missing_extension_as_parse_error()
  local ui, recorded = make_ui()
  reaper.DataSource_Parse = nil

  ui:parse_spreadsheet()

  lu.assertEquals(ui.parse_error, ScriptMaterialExcelSpreadsheetUI.MISSING_EXTENSION_MESSAGE)
  lu.assertStrContains(ui.parse_error, 'reaper-datasource')
  lu.assertNotEquals(ui.material_config.is_parsed, true)
  lu.assertEquals(recorded.events, {})
  lu.assertNil(recorded.saved)
end

function TestMissingExtension:test_retry_after_install_parses()
  local ui = make_ui()
  reaper.DataSource_Parse = nil
  ui:parse_spreadsheet()
  lu.assertNotNil(ui.parse_error)

  reaper.DataSource_Parse = function()
    return true, WORKBOOK_JSON
  end
  ui:parse_spreadsheet()

  lu.assertNil(ui.parse_error)
  lu.assertEquals(ui.material_config.is_parsed, true)
end

os.exit(lu.LuaUnit.run())
