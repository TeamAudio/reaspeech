package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/TableUtils')

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

function TestTableUtils:testShallowClone()
  local original = {1, 2, 3}
  local clone = table.shallow_clone(original)

  lu.assertNotIs(original, clone)
  lu.assertEquals(original, clone)
end

os.exit(lu.LuaUnit.run())