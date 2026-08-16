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

IntervalFunction = function()
  return {
    new = function(_, fn)
      return { fn = fn, react = function() fn() end }
    end
  }
end

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
  local recorded = { events = {}, saved = nil, posts = {} }

  local storage = {
    get = function() return { worksheets = {} } end,
    set = function(_, material) recorded.saved = material end,
  }

  ReaSpeechAPI = {
    post_request = function(_, endpoint, params, files)
      table.insert(recorded.posts, { endpoint = endpoint, params = params, files = files })
      return recorded.next_request
    end
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
  lu.assertNil(ui.parse_request)
  lu.assertNil(ui.parse_error)
  lu.assertEquals(recorded.events, { 'script_material_updated' })
  lu.assertEquals(recorded.saved, ui.material_config)
  lu.assertEquals(#recorded.posts, 0, 'native path must not hit the backend')
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

TestBackendFallback = {}

function TestBackendFallback:test_posts_to_backend_without_extension()
  local ui, recorded = make_ui()
  reaper.DataSource_Parse = nil
  recorded.next_request = { ready = function() return false end }

  ui:parse_spreadsheet()

  lu.assertEquals(#recorded.posts, 1)
  lu.assertEquals(recorded.posts[1].endpoint, '/script_match/parse_spreadsheet')
  lu.assertEquals(recorded.posts[1].files, { spreadsheet = '/tmp/lines.xlsx' })
  lu.assertNotNil(ui.parse_request)
end

function TestBackendFallback:test_request_error_clears_in_flight_state()
  local ui, recorded = make_ui()
  reaper.DataSource_Parse = nil
  recorded.next_request = {
    ready = function() return true end,
    error = function() return 'could not connect' end,
  }

  ui:parse_spreadsheet()
  ui.parse_interval.react()

  lu.assertEquals(ui.parse_error, 'could not connect')
  lu.assertNil(ui.parse_request)
  lu.assertNil(ui.parse_interval)
end

function TestBackendFallback:test_response_completes_parse()
  local ui, recorded = make_ui()
  reaper.DataSource_Parse = nil
  recorded.next_request = {
    ready = function() return true end,
    error = function() return nil end,
    result = function() return json.decode(WORKBOOK_JSON) end,
  }

  ui:parse_spreadsheet()
  ui.parse_interval.react()

  lu.assertEquals(ui.material_config.is_parsed, true)
  lu.assertNil(ui.parse_request)
  lu.assertNil(ui.parse_interval)
  lu.assertNil(ui.parse_error)
  lu.assertEquals(recorded.events, { 'script_material_updated' })
end

os.exit(lu.LuaUnit.run())
