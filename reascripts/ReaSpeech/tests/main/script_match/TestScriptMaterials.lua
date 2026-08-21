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

require('main/script_match/setup/needle/ScriptMaterialExcelSpreadsheet')
require('main/script_match/setup/needle/ScriptMaterials')

reaper = reaper or {}

--

TestGetSupportedExtensions = {}

-- Parse the dialog map into description -> set-of-extensions, order-
-- insensitively (comma order within a key is pairs()-dependent)
local function extensions_by_description(result)
  local by_description = {}
  for key, description in pairs(result) do
    lu.assertNil(key:find('%.'))
    local extensions = {}
    for part in key:gmatch('[^,]+') do
      extensions[part] = true
    end
    by_description[description] = extensions
  end
  return by_description
end

-- The result feeds Widgets.FileSelector.simple_open, which formats each
-- key as '*.<key>' (comma keys become '*.a;*.b'): keys must be dotless
-- or the dialog filter matches nothing
function TestGetSupportedExtensions:testDialogShape()
  local fake_service = { handlers = { ScriptMaterialExcelSpreadsheet } }

  local result = ScriptMaterials.get_supported_extensions(fake_service)

  lu.assertEquals(extensions_by_description(result), {
    ['Excel Spreadsheet'] = { xls = true, xlsx = true, xlsm = true, xlsb = true },
    ['OpenDocument Spreadsheet'] = { ods = true },
    ['CSV/TSV'] = { csv = true, tsv = true },
  })
end

--

TestMaterialFileSubpaths = {}

-- The sweep deletes exactly these; the shape must track the storage
-- layout (material config, needle store, one suggestion file per needle)
function TestMaterialFileSubpaths:testListsConfigNeedlesAndSuggestions()
  local materials = setmetatable({ session_id = 'SESSION' }, { __index = ScriptMaterials })

  local subpaths = materials:material_file_subpaths('MAT', { 'N1', 'N2' })

  lu.assertEquals(subpaths, {
    'reaspeech/script_match/sessions/SESSION/script_materials/MAT.json',
    'reaspeech/script_match/sessions/SESSION/needles/MAT.json',
    'reaspeech/script_match/sessions/SESSION/suggestions/N1.json',
    'reaspeech/script_match/sessions/SESSION/suggestions/N2.json',
  })
end

function TestMaterialFileSubpaths:testNoNeedles()
  local materials = setmetatable({ session_id = 'S' }, { __index = ScriptMaterials })
  lu.assertEquals(#materials:material_file_subpaths('M', {}), 2)
end

--

os.exit(lu.LuaUnit.run())
