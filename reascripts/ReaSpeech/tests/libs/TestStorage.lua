package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('vendor/json')

require('libs/Storage')

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

--

reaper.file_exists = reaper.file_exists or function(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

reaper.RecursiveCreateDirectory = reaper.RecursiveCreateDirectory or function() end

TestJSONFileCache = {}

function TestJSONFileCache:setUp()
  reaper.__test_setUp()
  self.filepath = os.tmpname()
  Storage.JSONFile.invalidate()
end

function TestJSONFileCache:tearDown()
  os.remove(self.filepath)
end

function TestJSONFileCache:testRoundTrip()
  local cell = Storage.JSONFile(self.filepath):table('things', {})
  cell:set({ 'a', 'b' })
  lu.assertEquals(cell:get(), { 'a', 'b' })
end

function TestJSONFileCache:testReadsSharedAcrossInstances()
  Storage.JSONFile(self.filepath):table('things', {}):set({ 'a' })

  -- A second engine on the same path sees the write via the cache
  local reader = Storage.JSONFile(self.filepath):table('things', {})
  lu.assertEquals(reader:get(), { 'a' })

  -- Once cached, reads no longer touch the file
  os.remove(self.filepath)
  lu.assertEquals(reader:get(), { 'a' })
end

function TestJSONFileCache:testInvalidateRereadsFromDisk()
  local cell = Storage.JSONFile(self.filepath):table('things', {})
  cell:set({ 'a' })

  os.remove(self.filepath)
  Storage.JSONFile.invalidate(self.filepath)

  lu.assertEquals(cell:get(), {})
end

function TestJSONFileCache:testRepeatedWritesWithNonReplacingRename()
  -- Windows os.rename fails when the destination exists; saving must
  -- fall back to remove-then-rename
  local real_rename = os.rename
  os.rename = function(from, to)
    local f = io.open(to, 'r')
    if f then
      f:close()
      return nil, 'destination exists'
    end
    return real_rename(from, to)
  end

  local ok, err = pcall(function()
    local cell = Storage.JSONFile(self.filepath):table('things', {})
    cell:set({ 'a' })
    cell:set({ 'a', 'b' })

    Storage.JSONFile.invalidate(self.filepath)
    lu.assertEquals(cell:get(), { 'a', 'b' })
  end)

  os.rename = real_rename
  lu.assertTrue(ok, tostring(err))
end

function TestJSONFileCache:testCreatesMissingParentDirectories()
  local created = {}
  local real_rcd = reaper.RecursiveCreateDirectory
  reaper.RecursiveCreateDirectory = function(dir, _)
    table.insert(created, dir)
    os.execute('mkdir -p "' .. dir .. '"')
    return 0
  end

  local base = self.filepath .. '-dir'
  local filepath = base .. '/nested/data.json'
  local ok, err = pcall(function()
    Storage.JSONFile(filepath):table('things', {}):set({ 'a' })
  end)

  reaper.RecursiveCreateDirectory = real_rcd
  os.execute('rm -rf "' .. base .. '"')

  lu.assertTrue(ok, tostring(err))
  -- the full absolute parent path, in a single call
  lu.assertEquals(created, { base .. '/nested' })
end

os.exit(lu.LuaUnit.run())
