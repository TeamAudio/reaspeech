package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('TableUtils')

--

TestTableUtils = {}

function TestTableUtils:testFlattenMethodExists()
  lu.assertNotNil(table['flatten'])
  lu.assertEquals(type(table['flatten']), 'function')
end

function TestTableUtils:testFlatten()
  local tables = {
    {1, 2, 3},
    {4, 5, 6},
    {7, 8, 9},
  }

  local result = table.flatten(tables)

  lu.assertEquals(result, {1, 2, 3, 4, 5, 6, 7, 8, 9})
end

os.exit(lu.LuaUnit.run())