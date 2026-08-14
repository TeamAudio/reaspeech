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

--

TestGetSupportedExtensions = {}

-- The result feeds Widgets.FileSelector.simple_open, which formats each
-- key as '*.<key>' (comma keys become '*.a;*.b'): keys must be dotless
-- or the dialog filter matches nothing
function TestGetSupportedExtensions:testDialogShape()
  local fake_service = { handlers = { ScriptMaterialExcelSpreadsheet } }

  local result = ScriptMaterials.get_supported_extensions(fake_service)

  local count, key, description = 0, nil, nil
  for k, v in pairs(result) do
    count = count + 1
    key, description = k, v
  end

  lu.assertEquals(count, 1)
  lu.assertEquals(description, 'Excel Spreadsheet')
  lu.assertNil(key:find('%.'))

  local extensions = {}
  for part in key:gmatch('[^,]+') do
    extensions[part] = true
  end
  lu.assertEquals(extensions, { xls = true, xlsx = true })
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
