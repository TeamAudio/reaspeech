package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('Polo')
require('ReaUtil')
require('Storage')
require('mock_reaper')
require('ReaIter')

require('source/AlertPopup')
require('source/ColumnLayout')
require('source/KeyMap')
require('source/Logging')
require('source/ReaSpeechActionsUI')
require('source/ReaSpeechAPI')
require('source/ReaSpeechControlsUI')
require('source/ReaSpeechPlugins')
require('source/ReaSpeechUI')
require('source/ReaSpeechWelcomeUI')
require('source/ReaSpeechWidgets')
require('source/ReaSpeechWorker')
require('source/Transcript')
require('source/TranscriptAnnotations')
require('source/TranscriptAnnotationsUI')
require('source/TranscriptEditor')
require('source/TranscriptExporter')
require('source/TranscriptUI')
require('source/WhisperLanguages')

--

TestReaSpeechUI = {}

function TestReaSpeechUI:setUp()
  reaper.__test_setUp()
  Script = {
    host = "localhost:9000"
  }
  self.app = ReaSpeechUI.new()
end

function TestReaSpeechUI:testInit()
  lu.assertEquals(#self.app.requests, 0)
  lu.assertEquals(#self.app.responses, 0)
end

--

os.exit(lu.LuaUnit.run())
