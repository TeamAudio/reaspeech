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

PathUtil = {
  normalize = function(path) return path end,
}

require('main/script_match/setup/needle/ScriptMaterialExcelSpreadsheet')
require('main/script_match/setup/ProjectFolderScan')

-- Scripted directory tree: dirs -> { files = {...}, subdirs = {...} }
local tree

reaper = reaper or {}
reaper.EnumProjects = function() return nil, '/proj/session.rpp' end
reaper.GetProjectPathEx = function() return '/proj/Media' end
reaper.EnumerateFiles = function(dir, index)
  local node = tree[dir]
  return node and node.files[index + 1] or nil
end
reaper.EnumerateSubdirectories = function(dir, index)
  local node = tree[dir]
  return node and node.subdirs[index + 1] or nil
end

-- File heads for the transcript sniff, keyed by full path
local heads

local function scanner()
  return ProjectFolderScan.new {
    read_head = function(filepath) return heads[filepath] end,
  }
end

--

TestProjectFolderScan = {}

function TestProjectFolderScan:setUp()
  tree = { ['/proj'] = { files = {}, subdirs = {} } }
  heads = {}
  reaper.DataSource_Parse = nil
end

function TestProjectFolderScan:testClassifiesTranscriptsAndSpreadsheets()
  tree['/proj'].files = { 'lines.xlsx', 'take1.json', 'notes.txt', 'settings.json' }
  heads['/proj/take1.json'] = '{"segments": [{"start": 0}]}'
  heads['/proj/settings.json'] = '{"volume": 1}'

  local results = scanner():scan()

  lu.assertEquals(results.transcripts, { '/proj/take1.json' })
  lu.assertEquals(results.spreadsheets, { '/proj/lines.xlsx' })
end

-- The spreadsheet list follows import gating: csv counts only when
-- the native parser is present
function TestProjectFolderScan:testSpreadsheetGatingIsCapabilityAware()
  tree['/proj'].files = { 'lines.csv' }

  lu.assertEquals(#scanner():scan().spreadsheets, 0)

  reaper.DataSource_Parse = function() end
  lu.assertEquals(scanner():scan().spreadsheets, { '/proj/lines.csv' })
end

function TestProjectFolderScan:testSkipsReaSpeechStorageAndDotDirs()
  tree['/proj'].subdirs = { 'reaspeech', 'reaspeech_export', '.git', 'Media' }
  tree['/proj/reaspeech'] = { files = { 'internal.json' }, subdirs = {} }
  tree['/proj/reaspeech_export'] = { files = { 'out.xlsx' }, subdirs = {} }
  tree['/proj/.git'] = { files = { 'config.json' }, subdirs = {} }
  tree['/proj/Media'] = { files = { 'vo.json' }, subdirs = {} }
  heads['/proj/reaspeech/internal.json'] = '{"segments": []}'
  heads['/proj/.git/config.json'] = '{"segments": []}'
  heads['/proj/Media/vo.json'] = '{"segments": []}'

  local results = scanner():scan()

  lu.assertEquals(results.transcripts, { '/proj/Media/vo.json' })
  lu.assertEquals(#results.spreadsheets, 0)
end

function TestProjectFolderScan:testDepthIsBounded()
  tree['/proj'].subdirs = { 'a' }
  tree['/proj/a'] = { files = { 'shallow.xlsx' }, subdirs = { 'b' } }
  tree['/proj/a/b'] = { files = { 'deep.xlsx' }, subdirs = {} }

  local results = scanner():scan()

  lu.assertEquals(results.spreadsheets, { '/proj/a/shallow.xlsx' })
end

function TestProjectFolderScan:testResultsAreSorted()
  tree['/proj'].files = { 'zebra.xlsx', 'aardvark.xlsx' }

  lu.assertEquals(scanner():scan().spreadsheets,
    { '/proj/aardvark.xlsx', '/proj/zebra.xlsx' })
end

function TestProjectFolderScan:testDotFilesAndMissingProjectPathAreSafe()
  tree['/proj'].files = { '.hidden.json' }
  heads['/proj/.hidden.json'] = '{"segments": []}'
  lu.assertEquals(#scanner():scan().transcripts, 0)

  reaper.EnumProjects = function() return nil, '' end
  reaper.GetProjectPathEx = function() return '' end
  local results = scanner():scan()
  lu.assertEquals(#results.transcripts, 0)
  lu.assertEquals(#results.spreadsheets, 0)
  reaper.EnumProjects = function() return nil, '/proj/session.rpp' end
  reaper.GetProjectPathEx = function() return '/proj/Media' end
end

-- The scan roots: the .RPP's directory is primary (GetProjectPathEx
-- alone returns the MEDIA directory and would miss files beside the
-- project file); an external media path joins as a second root, an
-- internal one is already covered by the walk
function TestProjectFolderScan:testScansProjectDirNotJustMediaPath()
  tree['/proj'].files = { 'lines.xlsx' }
  tree['/proj'].subdirs = { 'Media' }
  tree['/proj/Media'] = { files = { 'vo.json' }, subdirs = {} }
  heads['/proj/Media/vo.json'] = '{"segments": []}'

  local results = scanner():scan()

  lu.assertEquals(results.spreadsheets, { '/proj/lines.xlsx' })
  lu.assertEquals(results.transcripts, { '/proj/Media/vo.json' })
end

function TestProjectFolderScan:testExternalMediaPathJoinsAsSecondRoot()
  reaper.GetProjectPathEx = function() return '/elsewhere/audio' end
  tree['/proj'].files = { 'lines.xlsx' }
  tree['/elsewhere/audio'] = { files = { 'vo.json' }, subdirs = {} }
  heads['/elsewhere/audio/vo.json'] = '{"segments": []}'

  local results = scanner():scan()

  lu.assertEquals(results.spreadsheets, { '/proj/lines.xlsx' })
  lu.assertEquals(results.transcripts, { '/elsewhere/audio/vo.json' })
  reaper.GetProjectPathEx = function() return '/proj/Media' end
end

--

os.exit(lu.LuaUnit.run())
