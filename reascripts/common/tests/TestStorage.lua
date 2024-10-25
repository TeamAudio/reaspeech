package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('Storage')

require('json')
require('mock_reaper')

--

TestStorage = {}

function TestStorage:setUp()
  reaper.__test_setUp()
end

function TestStorage:testExtState()
  local settings = Storage.ExtState.make {
    section = 'MyScript.Settings',
    persist = true,
  }

  local my_setting = settings:boolean('my_setting', true)
  local my_number = settings:number('my_number', 42)
  local my_string = settings:string('my_string', 'hello')

  local my_setting_value = my_setting:get()
  lu.assertEquals(my_setting_value, true)
  my_setting:set(not my_setting_value)
  lu.assertEquals(my_setting:get(), false)
  my_setting:erase()
  lu.assertEquals(my_setting:get(), true)

  local my_number_value = my_number:get()
  lu.assertEquals(my_number_value, 42)
  my_number:set(my_number_value + 1)
  lu.assertEquals(my_number:get(), 43)
  my_number:erase()
  lu.assertEquals(my_number:get(), 42)

  local my_string_value = my_string:get()
  my_string:set(my_string_value .. ' world')
  lu.assertEquals(my_string:get(), 'hello world')
  my_string:erase()
  lu.assertEquals(my_string:get(), 'hello')

  local my_table = settings:table('my_table', {})
  local my_table_raw = settings:string('my_table', '{}')

  local my_table_value = my_table:get()
  lu.assertEquals(my_table_value, {})
  my_table:set({ key = 'value' })
  lu.assertEquals(my_table:get(), { key = 'value' })
  lu.assertEquals(my_table_raw:get(), '{"key":"value"}')

  my_table:erase()
  lu.assertEquals(my_table:get(), {})

  my_table:set({ 1, 2, 3 })
  lu.assertEquals(my_table:get(), { 1, 2, 3 })
  lu.assertEquals(my_table_raw:get(), '[1,2,3]')
end

function TestStorage:testProjExtState()
  local settings = Storage.ProjExtState.make {
    project = 0,
    extname = 'MyExtension',
  }

  local my_setting = settings:boolean('my_setting', true)
  local my_number = settings:number('my_number', 42)
  local my_string = settings:string('my_string', 'hello')

  local my_setting_value = my_setting:get()
  lu.assertEquals(my_setting_value, true)
  my_setting:set(not my_setting_value)
  lu.assertEquals(my_setting:get(), false)
  my_setting:erase()
  lu.assertEquals(my_setting:get(), true)

  local my_number_value = my_number:get()
  lu.assertEquals(my_number_value, 42)
  my_number:set(my_number_value + 1)
  lu.assertEquals(my_number:get(), 43)
  my_number:erase()
  lu.assertEquals(my_number:get(), 42)

  local my_string_value = my_string:get()
  my_string:set(my_string_value .. ' world')
  lu.assertEquals(my_string:get(), 'hello world')
  my_string:erase()
  lu.assertEquals(my_string:get(), 'hello')

  local my_table = settings:table('my_table', {})
  local my_table_raw = settings:string('my_table', '{}')

  local my_table_value = my_table:get()
  lu.assertEquals(my_table_value, {})
  my_table:set({ key = 'value' })
  lu.assertEquals(my_table:get(), { key = 'value' })
  lu.assertEquals(my_table_raw:get(), '{"key":"value"}')

  my_table:erase()
  lu.assertEquals(my_table:get(), {})

  my_table:set({ 1, 2, 3 })
  lu.assertEquals(my_table:get(), { 1, 2, 3 })
  lu.assertEquals(my_table_raw:get(), '[1,2,3]')
end

function TestStorage:testDerivedCell()
  local my_setting = Storage.memory('')

  local my_derived_setting = Storage.Cell.new {
    get = function () return my_setting:get():upper() end,
  }

  lu.assertEquals(my_derived_setting:get(), '')
  my_setting:set('test')
  lu.assertEquals(my_derived_setting:get(), 'TEST')

  lu.assertNil(my_derived_setting.set)
  lu.assertNil(my_derived_setting.erase)
end

os.exit(lu.LuaUnit.run())
