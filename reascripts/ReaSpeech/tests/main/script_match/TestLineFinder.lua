package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

require('main/script_match/setup/needle/LineFinder')

--

local ROWS = {
  { 'Filename', 'Character', 'Line' },
  { 'VO_001', 'SOLACE', 'Hello there' },
  { '', '', 'Scene direction, no character' },
  { 'VO_002', 'BRINE', 'Another line' },
  { 'VO_003', 'SOLACE', 'A third line' },
}

local NOT_BLANK_FILTERS = {
  { column = 1, type = 'is_not_blank' },
  { column = 2, type = 'is_not_blank' },
}

local function collect(finder)
  local found = {}
  for row_number, row in finder:find_lines() do
    table.insert(found, { row_number = row_number, row = row })
  end
  return found
end

--

TestLineFinder = {}

function TestLineFinder:testFiltersRows()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = NOT_BLANK_FILTERS,
    rows = ROWS,
  }
  local found = collect(finder)
  lu.assertEquals(#found, 3)
  lu.assertEquals(found[1].row_number, 2)
  lu.assertEquals(found[2].row_number, 4)
  lu.assertEquals(found[3].row_number, 5)
end

function TestLineFinder:testHeaderRowSkipped()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = {},
    rows = ROWS,
  }
  lu.assertEquals(collect(finder)[1].row_number, 2)
end

function TestLineFinder:testNoHeaderRowStartsAtOne()
  local finder = LineFinder.new {
    has_header_row = false,
    line_filters = {},
    rows = ROWS,
  }
  lu.assertEquals(collect(finder)[1].row_number, 1)
end

function TestLineFinder:testHiddenRowsSkippedByDefault()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = NOT_BLANK_FILTERS,
    rows = ROWS,
    hidden_rows = { 4 },
  }
  local found = collect(finder)
  lu.assertEquals(#found, 2)
  lu.assertEquals(found[1].row_number, 2)
  lu.assertEquals(found[2].row_number, 5)
end

function TestLineFinder:testHiddenRowsIncludedWhenDisabled()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = NOT_BLANK_FILTERS,
    rows = ROWS,
    hidden_rows = { 4 },
    skip_hidden_rows = false,
  }
  lu.assertEquals(#collect(finder), 3)
end

function TestLineFinder:testIsFilter()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = { { column = 2, type = 'is', value = 'SOLACE' } },
    rows = ROWS,
  }
  local found = collect(finder)
  lu.assertEquals(#found, 2)
  lu.assertEquals(found[1].row.Line, nil) -- rows are arrays, not records
  lu.assertEquals(found[1].row[3], 'Hello there')
end

function TestLineFinder:testContainsFilter()
  local finder = LineFinder.new {
    has_header_row = true,
    line_filters = { { column = 3, type = 'contains', value = 'third' } },
    rows = ROWS,
  }
  local found = collect(finder)
  lu.assertEquals(#found, 1)
  lu.assertEquals(found[1].row_number, 5)
end

--

os.exit(lu.LuaUnit.run())
