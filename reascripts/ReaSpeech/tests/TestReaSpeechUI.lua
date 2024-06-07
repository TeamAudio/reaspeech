package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('OptionsConfig')
require('Polo')
require('ReaUtil')
require('mock_reaper')

require('source/AlertPopup')
require('source/ReaSpeechAPI')
require('source/ReaSpeechProductActivation')
require('source/ReaSpeechUI')
require('source/ReaSpeechWorker')
require('source/Transcript')
require('source/TranscriptUI')
require('source/TranscriptEditor')
require('source/TranscriptExporter')

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
  lu.assertEquals(#self.app.logs, 0)
end

--

os.exit(lu.LuaUnit.run())
