package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('vendor/json')

require('libs/EnvUtil')
require('libs/PathUtil')
-- Deliberately loaded before libs/Storage: JSONStorage and
-- ProjectStorage define plain globals and must not depend on
-- Storage existing at load time
require('libs/storage/JSONStorage')
require('libs/storage/ProjectStorage')
require('libs/Storage')

--

TestProjectStorage = {}

function TestProjectStorage:setUp()
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

  JSONStorage.invalidate()
end

function TestProjectStorage:tearDown()
  reaper.GetOS = self._get_os
  reaper.file_exists = self._file_exists
  reaper.RecursiveCreateDirectory = self._rcd
  reaper.GetProjectPathEx = self._get_project_path

  os.execute('rm -rf "' .. self.project_dir .. '"')
end

function TestProjectStorage:testErrorsWithoutSavedProject()
  reaper.GetProjectPathEx = function() return '' end

  lu.assertErrorMsgContains('No project is open', function()
    ProjectStorage('reaspeech/config.json')
  end)
end

function TestProjectStorage:testWritesUnderProjectPath()
  local storage = ProjectStorage('reaspeech/config.json')
  storage:string('model', 'small'):set('medium')

  local f = assert(io.open(self.project_dir .. '/reaspeech/config.json', 'r'))
  local decoded = json.decode(f:read('*all'))
  f:close()

  lu.assertEquals(decoded._data.model, 'medium')
end

function TestProjectStorage:testNormalizesProjectPath()
  -- Windows-authored project paths can arrive with backslashes
  reaper.GetProjectPathEx = function()
    return (self.project_dir:gsub('/', '\\'))
  end

  ProjectStorage('config.json'):string('key', ''):set('value')

  local f = assert(io.open(self.project_dir .. '/config.json', 'r'))
  f:close()
end

function TestProjectStorage:testForwardsSchemaOptions()
  local storage = ProjectStorage('config.json', { schema_version = 3 })
  storage:string('key', ''):set('value')

  local f = assert(io.open(self.project_dir .. '/config.json', 'r'))
  local decoded = json.decode(f:read('*all'))
  f:close()

  lu.assertEquals(decoded._version, 3)
end

os.exit(lu.LuaUnit.run())
