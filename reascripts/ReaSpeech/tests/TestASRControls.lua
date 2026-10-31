package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('libs/Polo')
require('libs/Plugin')
require('libs/Storage')
require('libs/Logging')

require('ui/Widgets')
require('ui/ReaSpeechWidgets')
require('ui/widgets/Combo')
require('ui/widgets/Checkbox')
require('ui/widgets/TextInput')
require('ui/WhisperModels')
require('ui/WhisperLanguages')
require('ui/ReaSpeechControlsUI')
require('ui/ASRControls')

--

TestASRControls = {}

function TestASRControls:setUp()
  reaper.__test_setUp()

  -- Layouts and actions are unrelated to the settings being exercised.
  TranscriptImporter = { new = function() return {} end }
  ASRActions = { new = function() return {} end }
  AlertPopup = { new = function() return {} end }

  self.init_layouts = ASRControls.init_layouts
  ASRControls.init_layouts = function() end
end

function TestASRControls:tearDown()
  ASRControls.init_layouts = self.init_layouts
end

function TestASRControls:testUnsupportedStoredModelDefaultsToSmall()
  for _, name in ipairs({ 'tiny', 'base.en', 'large-v2', 'unknown', '' }) do
    reaper.SetExtState('ReaSpeech.ASR', 'model_name', name, true)

    local controls = ASRControls.new({})
    lu.assertEquals(controls.model_name:value(), 'small')
    lu.assertEquals(controls:get_request_data().model_name, 'small')

    lu.assertEquals(reaper.GetExtState('ReaSpeech.ASR', 'model_name'), 'small')
  end
end

function TestASRControls:testSupportedModelsArePreserved()
  for _, model in ipairs(WhisperModels.MODELS) do
    reaper.SetExtState('ReaSpeech.ASR', 'model_name', model.name, true)

    local controls = ASRControls.new({})
    lu.assertEquals(controls.model_name:value(), model.name)
  end
end

function TestASRControls:testStoredTurboTranslationIsReset()
  reaper.SetExtState('ReaSpeech.ASR', 'model_name', 'large-v3-turbo', true)
  reaper.SetExtState('ReaSpeech.ASR', 'translate', 'true', true)

  local controls = ASRControls.new({})
  lu.assertFalse(controls.translate:value())
  lu.assertTrue(controls.translate.options.disabled_if())

  lu.assertEquals(reaper.GetExtState('ReaSpeech.ASR', 'translate'), 'false')
end

function TestASRControls:testSelectingTurboResetsTranslation()
  local controls = ASRControls.new({})
  controls.translate:set(true)
  lu.assertTrue(controls:get_request_data().translate)

  controls.model_name:set('large-v3-turbo')
  controls.model_name.options.on_change('large-v3-turbo')
  lu.assertFalse(controls.translate:value())
  lu.assertTrue(controls.translate.options.disabled_if())

  controls.model_name:set('medium')
  controls.model_name.options.on_change('medium')
  lu.assertFalse(controls.translate.options.disabled_if())
  lu.assertFalse(controls.translate:value())

  controls.translate:set(true)
  lu.assertTrue(controls:get_request_data().translate)
end

--

os.exit(lu.LuaUnit.run())
