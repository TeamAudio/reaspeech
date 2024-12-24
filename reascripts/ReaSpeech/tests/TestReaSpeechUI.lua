package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('ImGuiTheme')
require('Polo')
require('ReaUtil')
require('Storage')
require('Trap')
require('mock_reaper')
require('ReaIter')

require('libs/ToolWindow')
require('source/AlertPopup')
require('source/ColumnLayout')
require('source/Fonts')
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
require('source/Theme')
require('source/Transcript')
require('source/TranscriptAnnotations')
require('source/TranscriptAnnotationsUI')
require('source/TranscriptEditor')
require('source/TranscriptExporter')
require('source/TranscriptImporter')
require('source/TranscriptUI')
require('source/WhisperLanguages')
require('source/Widgets')
require('source/components/widgets/Button')
require('source/components/widgets/ButtonBar')
require('source/components/widgets/Checkbox')
require('source/components/widgets/Combo')
require('source/components/widgets/FileSelector')
require('source/components/widgets/ListBox')
require('source/components/widgets/TabBar')
require('source/components/widgets/TextInput')

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
