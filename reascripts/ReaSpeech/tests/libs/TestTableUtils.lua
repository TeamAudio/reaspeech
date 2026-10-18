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

TestDeepCopy = {}

function TestDeepCopy:testCopiesNestedTablesWithoutSharing()
  local original = { a = 1, nested = { list = { 1, 2 }, flag = true } }
  local copy = table.deep_copy(original)

  lu.assertEquals(copy, original)
  lu.assertNotIs(copy, original)
  lu.assertNotIs(copy.nested, original.nested)
  lu.assertNotIs(copy.nested.list, original.nested.list)
end

function TestDeepCopy:testPassesThroughScalars()
  lu.assertEquals(table.deep_copy(42), 42)
  lu.assertEquals(table.deep_copy('x'), 'x')
  lu.assertNil(table.deep_copy(nil))
end

os.exit(lu.LuaUnit.run())