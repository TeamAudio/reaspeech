package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('vendor/json')

require('libs/EnvUtil')
require('libs/PathUtil')
require('libs/Storage')
require('libs/storage/ProjectJSON')

--

TestProjectJSON = {}

function TestProjectJSON:setUp()
  reaper.__test_setUp()

  self.project_dir = os.tmpname()
  os.remove(self.project_dir)
  os.execute('mkdir -p "' .. self.project_dir .. '"')

  self._get_os = reaper.GetOS
  self._file_exists = reaper.file_exists
  self._rcd = reaper.RecursiveCreateDirectory
  self._get_project_path = reaper.GetProjectPathEx

  reaper.GetOS = function() return 'OSX64' end
  reaper.file_exists = function(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
  end
  reaper.RecursiveCreateDirectory = function(dir, _)
    os.execute('mkdir -p "' .. dir .. '"')
    return 0
  end
  reaper.GetProjectPathEx = function() return self.project_dir end

  Storage.JSONFile.invalidate()
end

function TestProjectJSON:tearDown()
  reaper.GetOS = self._get_os
  reaper.file_exists = self._file_exists
  reaper.RecursiveCreateDirectory = self._rcd
  reaper.GetProjectPathEx = self._get_project_path

  os.execute('rm -rf "' .. self.project_dir .. '"')
end

function TestProjectJSON:testErrorsWithoutSavedProject()
  reaper.GetProjectPathEx = function() return '' end

  lu.assertErrorMsgContains('No project is open', function()
    Storage.ProjectJSON('reaspeech/config.json')
  end)
end

function TestProjectJSON:testWritesUnderProjectPath()
  local storage = Storage.ProjectJSON('reaspeech/config.json')
  storage:string('model', 'small'):set('medium')

  local f = assert(io.open(self.project_dir .. '/reaspeech/config.json', 'r'))
  local decoded = json.decode(f:read('*all'))
  f:close()

  lu.assertEquals(decoded._data.model, 'medium')
end

function TestProjectJSON:testNormalizesProjectPath()
  -- Windows-authored project paths can arrive with backslashes
  reaper.GetProjectPathEx = function()
    return (self.project_dir:gsub('/', '\\'))
  end

  Storage.ProjectJSON('config.json'):string('key', ''):set('value')

  local f = assert(io.open(self.project_dir .. '/config.json', 'r'))
  f:close()
end

function TestProjectJSON:testForwardsSchemaOptions()
  local storage = Storage.ProjectJSON('config.json', { schema_version = 3 })
  storage:string('key', ''):set('value')

  local f = assert(io.open(self.project_dir .. '/config.json', 'r'))
  local decoded = json.decode(f:read('*all'))
  f:close()

  lu.assertEquals(decoded._version, 3)
end

os.exit(lu.LuaUnit.run())
