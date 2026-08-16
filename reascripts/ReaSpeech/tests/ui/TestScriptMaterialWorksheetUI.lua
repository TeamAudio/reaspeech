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

require('ui/script_match/setup/needle/ScriptMaterialWorksheetUI')

--

local function worksheet_ui_with_config(config)
  return setmetatable({ config = config }, { __index = ScriptMaterialWorksheetUI })
end

-- Gates the Skip Hidden Rows checkbox: with nothing to skip, the
-- control is a no-op and stays hidden (always true for delimited files)
TestHasHiddenRows = {}

function TestHasHiddenRows:testHiddenRowsPresent()
  lu.assertTrue(worksheet_ui_with_config({ hidden_rows = { 4 } }):has_hidden_rows())
end

function TestHasHiddenRows:testEmptyHiddenRows()
  lu.assertFalse(worksheet_ui_with_config({ hidden_rows = {} }):has_hidden_rows())
end

function TestHasHiddenRows:testMissingHiddenRows()
  lu.assertFalse(worksheet_ui_with_config({}):has_hidden_rows())
end

--

os.exit(lu.LuaUnit.run())
