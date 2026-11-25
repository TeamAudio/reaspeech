package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('libs/ImGuiTheme')
require('libs/Logging')
require('libs/Polo')
require('libs/ReaIter')
require('libs/ReaUtil')
require('libs/Storage')
require('libs/ToolWindow')
require('libs/Trap')

require('ui/AlertPopup')
require('ui/ColumnLayout')
require('ui/Fonts')
require('ui/KeyMap')
require('ui/ReaSpeechControlsUI')
require('ui/ReaSpeechPlugins')
require('ui/ReaSpeechUI')
require('ui/ReaSpeechWidgets')
require('ui/Theme')
require('ui/TranscriptAnnotations')
require('ui/TranscriptAnnotationsUI')
require('ui/TranscriptEditor')
require('ui/TranscriptExporter')
require('ui/TranscriptImporter')
require('ui/TranscriptUI')
require('ui/Tween')
require('ui/WhisperLanguages')
require('ui/Widgets')
require('ui/widgets/Button')
require('ui/widgets/ButtonBar')
require('ui/widgets/Checkbox')
require('ui/widgets/Combo')
require('ui/widgets/FileSelector')
require('ui/widgets/ListBox')
require('ui/widgets/TabBar')
require('ui/widgets/TextInput')

require('main/ReaSpeechWorker')
require('main/Transcript')

--

TestReaSpeechUI = {}

function TestReaSpeechUI:setUp()
  reaper.__test_setUp()
  self.app = ReaSpeechUI.new()
end

function TestReaSpeechUI:testInit()
  lu.assertEquals(#self.app.requests, 0)
  lu.assertEquals(#self.app.responses, 0)
end

function TestReaSpeechUI:testExportDismissalUsesWrittenRevision()
  local transcript_ui = TranscriptUI.new {
    app = self.app,
    transcript = Transcript.new { name = 'Streaming transcript' },
  }
  local exporter = transcript_ui.transcript_exporter
  exporter:show_success()

  transcript_ui:mark_transcript_changed()
  exporter.alert_popup.onclose()
  lu.assertFalse(transcript_ui._transcript_saved)
  lu.assertFalse(transcript_ui:confirm_close())

  exporter:show_success()
  exporter.alert_popup.onclose()
  lu.assertTrue(transcript_ui:confirm_close())
end

--

os.exit(lu.LuaUnit.run())
