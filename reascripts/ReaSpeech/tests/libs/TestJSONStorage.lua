package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('vendor/json')

-- Deliberately loaded before libs/Storage: JSONStorage defines a
-- plain global and must not depend on Storage existing at load time
require('libs/storage/JSONStorage')
require('libs/Storage')

--

reaper.file_exists = reaper.file_exists or function(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

reaper.RecursiveCreateDirectory = reaper.RecursiveCreateDirectory or function() end

TestJSONStorage = {}

function TestJSONStorage:setUp()
  reaper.__test_setUp()
  self.filepath = os.tmpname()
  JSONStorage.invalidate()
end

function TestJSONStorage:tearDown()
  os.remove(self.filepath)
end

function TestJSONStorage:testRoundTrip()
  local cell = JSONStorage(self.filepath):table('things', {})
  cell:set({ 'a', 'b' })
  lu.assertEquals(cell:get(), { 'a', 'b' })
end

function TestJSONStorage:testReadsSharedAcrossInstances()
  JSONStorage(self.filepath):table('things', {}):set({ 'a' })

  -- A second engine on the same path sees the write via the cache
  local reader = JSONStorage(self.filepath):table('things', {})
  lu.assertEquals(reader:get(), { 'a' })

  -- Once cached, reads no longer touch the file
  os.remove(self.filepath)
  lu.assertEquals(reader:get(), { 'a' })
end

function TestJSONStorage:testInvalidateRereadsFromDisk()
  local cell = JSONStorage(self.filepath):table('things', {})
  cell:set({ 'a' })

  os.remove(self.filepath)
  JSONStorage.invalidate(self.filepath)

  lu.assertEquals(cell:get(), {})
end

function TestJSONStorage:testRepeatedWritesWithNonReplacingRename()
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
    local cell = JSONStorage(self.filepath):table('things', {})
    cell:set({ 'a' })
    cell:set({ 'a', 'b' })

    JSONStorage.invalidate(self.filepath)
    lu.assertEquals(cell:get(), { 'a', 'b' })
  end)

  os.rename = real_rename
  lu.assertTrue(ok, tostring(err))
end

function TestJSONStorage:testCreatesMissingParentDirectories()
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
    JSONStorage(filepath):table('things', {}):set({ 'a' })
  end)

  reaper.RecursiveCreateDirectory = real_rcd
  os.execute('rm -rf "' .. base .. '"')

  lu.assertTrue(ok, tostring(err))
  -- the full absolute parent path, in a single call
  lu.assertEquals(created, { base .. '/nested' })
end

os.exit(lu.LuaUnit.run())
