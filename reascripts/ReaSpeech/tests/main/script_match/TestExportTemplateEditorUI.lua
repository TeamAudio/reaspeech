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

Trap = function(f)
  return (pcall(f))
end

reaper = {
  genGuid = function() return '{WIDGET-GUID}' end,
  GetOS = function() return 'OSX64' end,
}

Storage = {
  memory = function(default)
    local value = default
    return {
      get = function() return value end,
      set = function(_self, v) value = v end,
    }
  end
}

require('libs/EnvUtil')
require('libs/PathUtil')
require('ui/Widgets')
require('ui/ReaSpeechWidgets')
require('ui/widgets/TextInput')
require('main/script_match/export/ExportTemplateEngine')
require('ui/script_match/export/ExportTemplateEditorUI')

--

local function make_metadata_service()
  return {
    get_variables_for_template_editor = function()
      return {
        { name = 'character', description = 'Character name', type = 'dynamic' },
        { name = 'asset_filename', description = 'Game asset filename', type = 'dynamic' },
      }
    end,
    get_sample_needles_for_preview = function() return {} end,
    get_variable_value = function() return nil end,
  }
end

local function make_settings(template)
  local state = Storage.memory(template or '')
  return {
    template = state,
    get_template = function() return state.get() end,
    set_template = function(_self, value) state:set(value) end,
  }
end

local function make_editor(template)
  return ExportTemplateEditorUI.new {
    settings = make_settings(template),
    needle_metadata_service = make_metadata_service(),
  }
end

local function match_names(editor)
  local names = {}
  for _, match in ipairs(editor._autocomplete.matches) do
    table.insert(names, match.name)
  end
  return names
end

--

TestAutocomplete = {}

function TestAutocomplete:testNoBlockNoAutocomplete()
  local editor = make_editor()
  editor:update_autocomplete('plain_name.wav')
  lu.assertIsNil(editor._autocomplete)
end

function TestAutocomplete:testOpenBraceShowsVariables()
  local editor = make_editor()
  editor:update_autocomplete('${')
  lu.assertNotIsNil(editor._autocomplete)
  local names = table.concat(match_names(editor), ',')
  lu.assertStrContains(names, 'character')
  lu.assertStrContains(names, 'asset_filename')
  lu.assertStrContains(names, 'output_format') -- system variables included
end

function TestAutocomplete:testPartialNarrows()
  local editor = make_editor()
  editor:update_autocomplete('${cha')
  lu.assertEquals(match_names(editor), { 'character' })
end

function TestAutocomplete:testNoMatchesHides()
  local editor = make_editor()
  editor:update_autocomplete('${zzz')
  lu.assertIsNil(editor._autocomplete)
end

function TestAutocomplete:testClosedBlockHides()
  local editor = make_editor()
  editor:update_autocomplete('${character}')
  lu.assertIsNil(editor._autocomplete)
end

function TestAutocomplete:testWhitespaceHides()
  local editor = make_editor()
  editor:update_autocomplete('${cha racter')
  lu.assertIsNil(editor._autocomplete)
end

function TestAutocomplete:testColonSwitchesToProcessors()
  local editor = make_editor()
  editor:update_autocomplete('${character:')
  local names = table.concat(match_names(editor), ',')
  lu.assertStrContains(names, 'slugify')
  lu.assertStrContains(names, 'basename')
end

function TestAutocomplete:testConditionalPrefixRidesAlong()
  local editor = make_editor()
  editor:update_autocomplete('${"-":cha')
  lu.assertEquals(match_names(editor), { 'character' })
  lu.assertEquals(editor._autocomplete.prefix, '${"-":')
end

function TestAutocomplete:testConditionalPrefixProcessorCompletes()
  local editor = make_editor()
  editor:update_autocomplete('${"-":character:slu')
  lu.assertEquals(match_names(editor), { 'slugify' })
  lu.assertEquals(editor._autocomplete.prefix, '${"-":character:')
end

function TestAutocomplete:testProcessorPartialNarrows()
  local editor = make_editor()
  editor:update_autocomplete('${character:slu')
  lu.assertEquals(match_names(editor), { 'slugify' })
end

function TestAutocomplete:testLastUnclosedBlockWins()
  local editor = make_editor()
  editor:update_autocomplete('${character}/take_${asset')
  lu.assertEquals(match_names(editor), { 'asset_filename' })
end

function TestAutocomplete:testApplyCompletesVariable()
  local editor = make_editor()
  editor:update_autocomplete('abc/${cha')
  editor:apply_autocomplete('character')

  lu.assertEquals(editor.settings:get_template(), 'abc/${character}')
  lu.assertIsNil(editor._autocomplete)
end

function TestAutocomplete:testApplyCompletesProcessor()
  local editor = make_editor()
  editor:update_autocomplete('${character:slu')
  editor:apply_autocomplete('slugify')

  lu.assertEquals(editor.settings:get_template(), '${character:slugify}')
end

--

TestTemplatePathRules = {}

function TestTemplatePathRules:make_engine()
  return ExportTemplateEngine.new { needle_metadata_service = make_metadata_service() }
end

function TestTemplatePathRules:testRelativePrefixStaysInTree()
  local engine = self:make_engine()
  lu.assertEquals(
    engine:get_relative_path_from_filename(
      'session_export/${asset_filename}.wav', 'session_export/VO_001.wav'),
    'session_export/VO_001.wav')
end

function TestTemplatePathRules:testAbsolutePrefixStripped()
  local engine = self:make_engine()
  lu.assertEquals(
    engine:get_relative_path_from_filename(
      '/Users/me/GameAudio/${asset_filename}.wav', '/Users/me/GameAudio/VO_001.wav'),
    'VO_001.wav')
end

function TestTemplatePathRules:testNoPrefixReturnsFilename()
  local engine = self:make_engine()
  lu.assertEquals(
    engine:get_relative_path_from_filename('${asset_filename}.wav', 'VO_001.wav'),
    'VO_001.wav')
end

--

TestProcessorTargeting = {}

function TestProcessorTargeting:testNoTargetIsNoOp()
  local editor = make_editor('take${incrementing_number}.wav')
  editor:apply_processor('slugify')
  lu.assertEquals(editor.settings.get_template(), 'take${incrementing_number}.wav')
end

function TestProcessorTargeting:testAppliesToLastInsertedVariable()
  local editor = make_editor('take${incrementing_number}.wav')
  editor:insert_variable('character')
  editor:apply_processor('slugify')
  lu.assertEquals(editor.settings.get_template(),
    'take${incrementing_number}.wav${character:slugify}')
end

function TestProcessorTargeting:testRepeatClickSwapsProcessor()
  local editor = make_editor('')
  editor:insert_variable('character')
  editor:apply_processor('slugify')
  editor:apply_processor('uppercase')
  lu.assertEquals(editor.settings.get_template(), '${character:uppercase}')
end

function TestProcessorTargeting:testEditedAwayBlockGoesInert()
  local editor = make_editor('')
  editor:insert_variable('character')
  editor.settings:set_template('plain.wav')
  editor:apply_processor('slugify')
  lu.assertEquals(editor.settings.get_template(), 'plain.wav')
end

function TestProcessorTargeting:testTargetsLastBlockOfThatVariable()
  local editor = make_editor('${character}-x')
  editor:insert_variable('character')
  editor:apply_processor('slugify')
  lu.assertEquals(editor.settings.get_template(),
    '${character}-x${character:slugify}')
end

--

os.exit(lu.LuaUnit.run())
