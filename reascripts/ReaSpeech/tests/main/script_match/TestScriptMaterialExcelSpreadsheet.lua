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

require('main/script_match/metadata_layers/TagsMetadataLayer')
require('main/script_match/setup/needle/LineFinder')
require('main/script_match/setup/needle/ScriptMaterialExcelSpreadsheet')

--

local function worksheet(name, options)
  options = options or {}
  return {
    config = {
      name = name,
      enabled = options.enabled,
      has_header_row = true,
      line_column = 3,
      line_filters = {
        { column = 1, type = 'is_not_blank' },
        { column = 2, type = 'is_not_blank' },
      },
      hidden_rows = options.hidden_rows or {},
      metadata_layers = options.metadata_layers,
      column_count = 3,
    },
    data = {
      { 'Filename', 'Character', 'Line' },
      { 'VO_001', 'SOLACE', 'First line' },
      { '', '', 'Scene direction' },
      { 'VO_002', 'BRINE', 'Second line' },
    },
  }
end

local function spreadsheet_with(worksheets)
  return ScriptMaterialExcelSpreadsheet.new {
    session_id = 'session-1',
    config = { worksheets = worksheets },
  }
end

reaper = reaper or {}

--

TestCanHandleFile = {}

function TestCanHandleFile:testAcceptsExcelFormats()
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.xlsx'))
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.xls'))
end

function TestCanHandleFile:testExtensionMatchIsCaseInsensitive()
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/SCRIPT.XLSX'))
end

-- Used to crash concatenating a nil extension
function TestCanHandleFile:testRejectsPathWithoutExtension()
  lu.assertFalse(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/README'))
end

-- Everything reaper-datasource reads is accepted; the parse step
-- reports the extension missing if it is
function TestCanHandleFile:testAcceptsAllNativeFormats()
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.csv'))
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.tsv'))
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.ods'))
  lu.assertTrue(ScriptMaterialExcelSpreadsheet:can_handle_file('/a/script.xlsb'))
end

--

TestScriptMaterialExcelSpreadsheet = {}

function TestScriptMaterialExcelSpreadsheet:testEnabledWorksheetProducesNeedles()
  local needles = spreadsheet_with({ worksheet('Sheet1', { enabled = true }) }):needles()
  lu.assertEquals(#needles, 2)
  lu.assertEquals(needles[1].content, 'First line')
  lu.assertEquals(needles[2].content, 'Second line')
  lu.assertEquals(needles[1].locator, 'worksheet_1:row_2')
  lu.assertEquals(needles[1].navigation, { 'Sheet1' })
end

function TestScriptMaterialExcelSpreadsheet:testDisabledWorksheetSkipped()
  local needles = spreadsheet_with({
    worksheet('Sheet1', { enabled = true }),
    worksheet('Sheet2', { enabled = false }),
    worksheet('Sheet3', {}), -- never configured; checkbox shows unchecked
  }):needles()
  lu.assertEquals(#needles, 2)
  for _, needle in ipairs(needles) do
    lu.assertEquals(needle.navigation, { 'Sheet1' })
  end
end

function TestScriptMaterialExcelSpreadsheet:testLocatorsUseStableWorksheetIndex()
  -- Disabling an earlier worksheet must not renumber later locators,
  -- or existing editorial decisions would attach to the wrong needles
  local needles = spreadsheet_with({
    worksheet('Sheet1', { enabled = false }),
    worksheet('Sheet2', { enabled = true }),
  }):needles()
  lu.assertEquals(#needles, 2)
  lu.assertStrContains(needles[1].locator, 'worksheet_2:')
end

function TestScriptMaterialExcelSpreadsheet:testHiddenRowsExcluded()
  local needles = spreadsheet_with({
    worksheet('Sheet1', { enabled = true, hidden_rows = { 4 } }),
  }):needles()
  lu.assertEquals(#needles, 1)
  lu.assertEquals(needles[1].content, 'First line')
end

function TestScriptMaterialExcelSpreadsheet:testTagsMetadata()
  local needles = spreadsheet_with({
    worksheet('Sheet1', {
      enabled = true,
      metadata_layers = {
        { key = 'tags', config = { predefined_tag = 'character', column_number = 2 } },
      },
    }),
  }):needles()
  lu.assertEquals(needles[1].metadata, {
    { type = 'tags', tag = 'character', value = 'SOLACE' },
  })
  lu.assertEquals(needles[2].metadata[1].value, 'BRINE')
end

-- The config UI displays column 1 for an untouched From Column combo,
-- but only change events used to persist it - a tag row left at the
-- default must still extract (against column 1)
function TestScriptMaterialExcelSpreadsheet:testTagsMetadataDefaultColumn()
  local needles = spreadsheet_with({
    worksheet('Sheet1', {
      enabled = true,
      metadata_layers = {
        { key = 'tags', config = { predefined_tag = 'custom', custom_tag = 'asset_filename' } },
      },
    }),
  }):needles()
  lu.assertEquals(needles[1].metadata, {
    { type = 'tags', tag = 'asset_filename', value = 'VO_001' },
  })
  lu.assertEquals(needles[2].metadata[1].value, 'VO_002')
end

function TestScriptMaterialExcelSpreadsheet:testTagsMetadataStaticValueNeedsNoColumn()
  local needles = spreadsheet_with({
    worksheet('Sheet1', {
      enabled = true,
      metadata_layers = {
        { key = 'tags', config = { predefined_tag = 'location', tag_value = 'Meridian' } },
      },
    }),
  }):needles()
  lu.assertEquals(needles[1].metadata, {
    { type = 'tags', tag = 'location', value = 'Meridian' },
  })
end

-- An untouched tag combo leaves predefined_tag empty; a nameless tag
-- must not extract (empty string is truthy in Lua - the guard needs
-- an explicit check)
function TestScriptMaterialExcelSpreadsheet:testTagsMetadataEmptyTagNameSkipped()
  local needles = spreadsheet_with({
    worksheet('Sheet1', {
      enabled = true,
      metadata_layers = {
        { key = 'tags', config = { predefined_tag = '', column_number = 2 } },
      },
    }),
  }):needles()
  lu.assertEquals(needles[1].metadata, {})
end

--

TestMergeWorksheetConfigs = {}

function TestMergeWorksheetConfigs:testUserConfigSurvivesReparse()
  local previous = { {
    config = {
      name = 'Sheet1', column_count = 4, row_count = 100,
      enabled = true, has_header_row = true, line_column = 2,
      metadata_layers = { { key = 'tags' } },
    },
    data = { { 'old' } },
  } }
  local fresh = { {
    config = { name = 'Sheet1', column_count = 5, row_count = 120, hidden_rows = { 3 } },
    data = { { 'new' } },
  } }

  local merged = ScriptMaterialExcelSpreadsheet.merge_worksheet_configs(previous, fresh)

  lu.assertEquals(#merged, 1)
  lu.assertEquals(merged[1].data, { { 'new' } })
  lu.assertEquals(merged[1].config.column_count, 5)
  lu.assertEquals(merged[1].config.row_count, 120)
  lu.assertEquals(merged[1].config.hidden_rows, { 3 })
  lu.assertEquals(merged[1].config.enabled, true)
  lu.assertEquals(merged[1].config.has_header_row, true)
  lu.assertEquals(merged[1].config.line_column, 2)
  lu.assertEquals(merged[1].config.metadata_layers, { { key = 'tags' } })
end

function TestMergeWorksheetConfigs:testNewAndVanishedSheets()
  local previous = { { config = { name = 'Gone', enabled = true } } }
  local fresh = { { config = { name = 'Brand New', column_count = 2 } } }

  local merged = ScriptMaterialExcelSpreadsheet.merge_worksheet_configs(previous, fresh)

  lu.assertEquals(#merged, 1)
  lu.assertEquals(merged[1].config.name, 'Brand New')
  lu.assertNil(merged[1].config.enabled)
end

function TestMergeWorksheetConfigs:testFirstParseHasNoPrevious()
  local fresh = { { config = { name = 'Sheet1', column_count = 3 } } }
  local merged = ScriptMaterialExcelSpreadsheet.merge_worksheet_configs(nil, fresh)
  lu.assertEquals(merged[1].config.column_count, 3)
end

--

TestPropagateWorksheetConfig = {}

local function make_source_sheet()
  return {
    config = {
      name = 'Source', column_count = 4, row_count = 10, enabled = true,
      has_header_row = true, line_column = 2,
      line_filters = { { column = 3, type = 'not_empty' } },
      metadata_layers = { { key = 'tags', config = { predefined_tag = 'character', column_number = 4 } } },
    },
  }
end

function TestPropagateWorksheetConfig:testCopiesUserConfigDeeply()
  local source = make_source_sheet()
  local target = { config = { name = 'Target', column_count = 6, row_count = 99, enabled = false } }

  local applied, skipped = ScriptMaterialExcelSpreadsheet.propagate_worksheet_config(
    source, { source, target })

  lu.assertEquals(applied, { 'Target' })
  lu.assertEquals(skipped, {})

  -- User config arrived
  lu.assertEquals(target.config.has_header_row, true)
  lu.assertEquals(target.config.line_column, 2)
  lu.assertEquals(target.config.line_filters, source.config.line_filters)
  lu.assertEquals(target.config.metadata_layers, source.config.metadata_layers)

  -- ...as copies, not shared tables
  lu.assertNotIs(target.config.line_filters, source.config.line_filters)
  lu.assertNotIs(target.config.metadata_layers[1].config, source.config.metadata_layers[1].config)

  -- Per-sheet identity fields stay
  lu.assertEquals(target.config.name, 'Target')
  lu.assertEquals(target.config.column_count, 6)
  lu.assertEquals(target.config.row_count, 99)
  lu.assertEquals(target.config.enabled, false)
end

function TestPropagateWorksheetConfig:testSkipsSheetsWithTooFewColumns()
  local source = make_source_sheet() -- references up to column 4
  local narrow = { config = { name = 'Narrow', column_count = 3 } }

  local applied, skipped = ScriptMaterialExcelSpreadsheet.propagate_worksheet_config(
    source, { source, narrow })

  lu.assertEquals(applied, {})
  lu.assertEquals(skipped, { 'Narrow' })
  lu.assertNil(narrow.config.line_column)
end

function TestPropagateWorksheetConfig:testMaxReferencedColumn()
  lu.assertEquals(ScriptMaterialExcelSpreadsheet.max_referenced_column(make_source_sheet().config), 4)
  lu.assertEquals(ScriptMaterialExcelSpreadsheet.max_referenced_column({}), 1)
end

--

TestConfigBlob = {}

function TestConfigBlob:testRoundTrip()
  local source = make_source_sheet()
  local blob = ScriptMaterialExcelSpreadsheet.export_config_blob(source)

  lu.assertStrContains(blob, 'RSWC:', true)

  local target = { config = { name = 'Target', column_count = 8, enabled = false } }
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob(blob, target)

  lu.assertEquals(message, 'Config pasted')
  lu.assertTrue(ok)
  lu.assertEquals(target.config.line_column, 2)
  lu.assertEquals(target.config.metadata_layers, source.config.metadata_layers)
  lu.assertNotIs(target.config.metadata_layers, source.config.metadata_layers)
  lu.assertEquals(target.config.name, 'Target')
  lu.assertEquals(target.config.enabled, false)
end

function TestConfigBlob:testRejectsForeignClipboard()
  local target = { config = { column_count = 8 } }
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob('hello world', target)
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'does not hold')
end

function TestConfigBlob:testRejectsDamagedBase64()
  local target = { config = { column_count = 8 } }
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob('RSWC:!!!not-base64', target)
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'bad base64')
end

function TestConfigBlob:testRejectsNewerVersion()
  local payload = json.encode({
    kind = 'reaspeech.worksheet_config', version = 99, config = {},
  })
  local blob = 'RSWC:' .. payload:base64_encode()
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob(blob, { config = { column_count = 8 } })
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'newer')
end

function TestConfigBlob:testRejectsTooFewColumns()
  local blob = ScriptMaterialExcelSpreadsheet.export_config_blob(make_source_sheet())
  local narrow = { config = { name = 'Narrow', column_count = 3 } }
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob(blob, narrow)
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'column')
  lu.assertNil(narrow.config.line_column)
end

function TestConfigBlob:testEmptyClipboard()
  local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob(nil, { config = {} })
  lu.assertFalse(ok)
  lu.assertStrContains(message, 'empty')
end

--

os.exit(lu.LuaUnit.run())
