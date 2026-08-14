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

reaper = {
  GetOS = function() return 'OSX64' end,
}

require('libs/EnvUtil')
require('libs/PathUtil')
require('main/script_match/export/ExportTemplateEngine')

local function make_engine()
  return ExportTemplateEngine.new {
    needle_metadata_service = {
      get_variable_value = function(_self, variable_name, data)
        return data[variable_name]
      end,
    },
  }
end

--
-- generate_filename: incrementing_number handling
--

TestGenerateFilename = {}

function TestGenerateFilename:testResolvesToOneForPreviews()
  local engine = make_engine()
  local filename = engine:generate_filename('${character}_${incrementing_number}.wav', { character = 'Brine' })
  lu.assertEquals(filename, 'Brine_1.wav')
end

function TestGenerateFilename:testDeferLeavesPlaceholderIntact()
  local engine = make_engine()
  local filename = engine:generate_filename('${character}_${incrementing_number}.wav', { character = 'Brine' }, true)
  lu.assertEquals(filename, 'Brine_${incrementing_number}.wav')
end

function TestGenerateFilename:testDeferLeavesProcessorPlaceholderIntact()
  local engine = make_engine()
  local filename = engine:generate_filename('${character}_${incrementing_number:padded}.wav', { character = 'Brine' }, true)
  lu.assertEquals(filename, 'Brine_${incrementing_number:padded}.wav')
end

--
-- finalize_filenames: batch numbering
--

TestFinalizeFilenames = {}

function TestFinalizeFilenames:testNumbersDuplicateGroups()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'take_${incrementing_number}.wav',
    'take_${incrementing_number}.wav',
    'other_${incrementing_number}.wav',
  })
  lu.assertEquals(finals, { 'take_1.wav', 'take_2.wav', 'other_1.wav' })
end

function TestFinalizeFilenames:testAppliesProcessor()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'take_${incrementing_number:padded}.wav',
    'take_${incrementing_number:padded}.wav',
  })
  lu.assertEquals(finals, { 'take_001.wav', 'take_002.wav' })
end

function TestFinalizeFilenames:testUnknownProcessorFallsBackToPlainNumber()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'take_${incrementing_number:nope}.wav',
    'take_${incrementing_number:nope}.wav',
  })
  lu.assertEquals(finals, { 'take_1.wav', 'take_2.wav' })
end

function TestFinalizeFilenames:testGroupsIgnorePlaceholderPosition()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'dir/${incrementing_number}_line.wav',
    'dir/${incrementing_number}_line.wav',
  })
  lu.assertEquals(finals, { 'dir/1_line.wav', 'dir/2_line.wav' })
end

--
-- finalize_filenames: collision safety net (no variable in template)
--

function TestFinalizeFilenames:testCollisionsWithoutVariableGetSuffixed()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'line.wav',
    'line.wav',
    'line.wav',
  })
  lu.assertEquals(finals, { 'line.wav', 'line_2.wav', 'line_3.wav' })
end

function TestFinalizeFilenames:testSuffixAvoidsExistingNames()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'line_2.wav',
    'line.wav',
    'line.wav',
  })
  lu.assertEquals(finals, { 'line_2.wav', 'line.wav', 'line_3.wav' })
end

function TestFinalizeFilenames:testSuffixLandsBeforeExtension()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'dir.v2/clip.wav',
    'dir.v2/clip.wav',
  })
  lu.assertEquals(finals, { 'dir.v2/clip.wav', 'dir.v2/clip_2.wav' })
end

function TestFinalizeFilenames:testExtensionlessCollisionSuffixesAtEnd()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'clip',
    'clip',
  })
  lu.assertEquals(finals, { 'clip', 'clip_2' })
end

--
-- Conditional prefix syntax: ${"-":variable:processor}
--

TestConditionalPrefix = {}

function TestConditionalPrefix:testPrefixRendersWithValue()
  local engine = make_engine()
  local filename = engine:generate_filename('line${needle_index}${"-":character}.wav',
    { needle_index = '7', character = 'Brine' })
  lu.assertEquals(filename, 'line7-Brine.wav')
end

function TestConditionalPrefix:testPrefixDropsWhenBlank()
  local engine = make_engine()
  local filename = engine:generate_filename('line${needle_index}${"-":character}.wav',
    { needle_index = '7' })
  lu.assertEquals(filename, 'line7.wav')
end

function TestConditionalPrefix:testPrefixTestsAfterProcessor()
  local engine = make_engine()
  -- slugify blanks a punctuation-only value; the prefix must drop too
  local filename = engine:generate_filename('x${"-":character:slugify}.wav',
    { character = '?!' })
  lu.assertEquals(filename, 'x.wav')
end

function TestConditionalPrefix:testChainSkipsBlankMiddle()
  local engine = make_engine()
  local filename = engine:generate_filename('${track_name}${"-":character}${"-":context}',
    { track_name = 'A', context = 'C' })
  lu.assertEquals(filename, 'A-C')
end

function TestConditionalPrefix:testDeferLeavesPrefixedPlaceholder()
  local engine = make_engine()
  local filename = engine:generate_filename('take${"-":incrementing_number}.wav', {}, true)
  lu.assertEquals(filename, 'take${"-":incrementing_number}.wav')
end

function TestConditionalPrefix:testFinalizeResolvesPrefixedPlaceholder()
  local engine = make_engine()
  local finals = engine:finalize_filenames({
    'take${"-":incrementing_number:padded}.wav',
    'take${"-":incrementing_number:padded}.wav',
  })
  lu.assertEquals(finals, { 'take-001.wav', 'take-002.wav' })
end

function TestConditionalPrefix:testValidPrefixTemplateHasNoErrors()
  local engine = make_engine()
  lu.assertEquals(engine:validate_template('${"-":character}.wav'), {})
end

function TestConditionalPrefix:testInvalidPrefixCharactersFlagged()
  local engine = make_engine()
  local errors = engine:validate_template('${"<":character}.wav')
  lu.assertEquals(#errors, 1)
  lu.assertStrContains(errors[1], 'prefix')
end

--
-- generate_realistic_preview: sample-needle shape from
-- NeedleMetadataService:get_sample_needles_for_preview
--

TestRealisticPreview = {}

function TestRealisticPreview:testSampleNeedleMetadataResolves()
  local engine = make_engine()
  local filename = engine:generate_realistic_preview(
    'session_export/${asset_filename}-${character:slugify}-take${incrementing_number}.wav',
    { {
      guid = 'g1',
      content = 'And why do you ask?',
      metadata = {
        asset_filename = 'VO_Moxie_zzqAct1SolaceIntroB01_E01_001',
        character = 'Solace Vesper',
        source_file = 'Script.xlsx',
        source_sheet = 'Sheet1',
      },
    } })
  lu.assertEquals(filename,
    'session_export/VO_Moxie_zzqAct1SolaceIntroB01_E01_001-solace_vesper-take1.wav')
end

function TestRealisticPreview:testPreviewSegmentsMarkSubstitutions()
  local engine = make_engine()
  local segments = engine:generate_preview_segments(
    'x/${character:slugify}-take${incrementing_number}.wav',
    { {
      guid = 'g1',
      content = 'line',
      metadata = { character = 'Solace Vesper' },
    } })
  lu.assertEquals(segments, {
    { text = 'x/' },
    { text = 'solace_vesper', from_template = true },
    { text = '-take' },
    { text = '1', from_template = true },
    { text = '.wav' },
  })
end

function TestRealisticPreview:testPreviewSegmentsSkipBlankValues()
  local engine = make_engine()
  local segments = engine:generate_preview_segments(
    '${no_such_variable}-x', { {
      guid = 'g1',
      content = 'line',
      metadata = { character = 'solace' },
    } })
  lu.assertEquals(segments, { { text = '-x' } })
end

function TestRealisticPreview:testSampleNeedleNavigationFromSource()
  local engine = make_engine()
  local filename = engine:generate_realistic_preview(
    '${navigation}/${character}.wav',
    { {
      guid = 'g1',
      content = 'line',
      metadata = {
        character = 'solace',
        source_file = 'Script.xlsx',
        source_sheet = 'Sheet1',
      },
    } })
  lu.assertEquals(filename, 'Script.xlsx/Sheet1/solace.wav')
end

--

os.exit(lu.LuaUnit.run())
