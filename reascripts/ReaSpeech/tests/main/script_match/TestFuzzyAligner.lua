package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('main/script_match/curation/matchers/TextNormalizer')
require('main/script_match/curation/matchers/FuzzyAligner')

--

local function stream_of(text)
  local words = {}
  for word in text:gmatch('%S+') do
    table.insert(words, word)
  end
  return FuzzyAligner.prepare_stream(words), words
end

local function match_phrase(needle_text, stream_text, options)
  local stream = stream_of(stream_text)
  local needle_tokens = TextNormalizer.tokenize(needle_text)
  return FuzzyAligner.find_matches(needle_tokens, stream, options)
end

--

TestLevenshtein = {}

function TestLevenshtein:testIdentical()
  lu.assertEquals(FuzzyAligner.levenshtein('word', 'word'), 0)
end

function TestLevenshtein:testEmpty()
  lu.assertEquals(FuzzyAligner.levenshtein('', 'word'), 4)
  lu.assertEquals(FuzzyAligner.levenshtein('word', ''), 4)
end

function TestLevenshtein:testSubstitution()
  lu.assertEquals(FuzzyAligner.levenshtein('word', 'ward'), 1)
end

function TestLevenshtein:testInsertionAndDeletion()
  lu.assertEquals(FuzzyAligner.levenshtein('word', 'words'), 1)
  lu.assertEquals(FuzzyAligner.levenshtein('words', 'word'), 1)
end

TestSimilarity = {}

function TestSimilarity:testExactIsOne()
  lu.assertEquals(FuzzyAligner.similarity('same', 'same'), 1.0)
end

function TestSimilarity:testTypoIsClose()
  lu.assertAlmostEquals(FuzzyAligner.similarity('purpose', 'porpose'), 6 / 7, 0.001)
end

function TestSimilarity:testUnrelatedIsLow()
  lu.assertIsTrue(FuzzyAligner.similarity('apple', 'zebra') < 0.3)
end

--

TestFuzzyAligner = {}

function TestFuzzyAligner:testExactMatchFullConfidence()
  local matches = match_phrase(
    'strike the core',
    'prelude words strike the core epilogue words')
  lu.assertEquals(#matches, 1)
  lu.assertEquals(matches[1].confidence, 1.0)
  lu.assertEquals(matches[1].start_index, 3)
  lu.assertEquals(matches[1].end_index, 5)
  lu.assertEquals(matches[1].matched_count, 3)
end

function TestFuzzyAligner:testPunctuationAndCaseDifferences()
  local matches = match_phrase(
    "Don't stop believing!",
    "some prelude don't STOP, believing... and more")
  lu.assertEquals(#matches, 1)
  lu.assertEquals(matches[1].confidence, 1.0)
  lu.assertEquals(matches[1].start_index, 3)
  lu.assertEquals(matches[1].end_index, 5)
end

function TestFuzzyAligner:testSubstitutedWordStillMatches()
  -- Whisper misheard one word as a similar one
  local matches = match_phrase(
    'seal the ancient gateway forever',
    'now we seal the ancient getaway forever done')
  lu.assertEquals(#matches, 1)
  lu.assertIsTrue(matches[1].confidence > 0.8)
  lu.assertIsTrue(matches[1].confidence < 1.0)
  lu.assertEquals(matches[1].start_index, 3)
  lu.assertEquals(matches[1].end_index, 7)
end

function TestFuzzyAligner:testInsertedFillerWordTolerated()
  local matches = match_phrase(
    'seal the ancient gateway',
    'we seal the um ancient gateway now')
  lu.assertEquals(#matches, 1)
  lu.assertIsTrue(matches[1].confidence > 0.8)
  lu.assertEquals(matches[1].start_index, 2)
  lu.assertEquals(matches[1].end_index, 6)
end

function TestFuzzyAligner:testDroppedWordTolerated()
  local matches = match_phrase(
    'seal the ancient gateway forever',
    'we seal the gateway forever now')
  lu.assertEquals(#matches, 1)
  lu.assertIsTrue(matches[1].confidence > 0.6)
  lu.assertEquals(matches[1].matched_count, 4)
end

function TestFuzzyAligner:testNoMatchWhenAbsent()
  local matches = match_phrase(
    'seal the ancient gateway',
    'completely unrelated transcript content here')
  lu.assertEquals(#matches, 0)
end

function TestFuzzyAligner:testGarbledMatchFallsBelowThreshold()
  local matches = match_phrase(
    'seal the ancient gateway forever tonight',
    'we seal something entirely different happens forever')
  lu.assertEquals(#matches, 0)
end

function TestFuzzyAligner:testMultipleTakesFoundSeparately()
  -- Two takes of the same line, back to back
  local matches = match_phrase(
    'strike the crystal core',
    'take one strike the crystal core again strike the crystal core done')
  lu.assertEquals(#matches, 2)
  lu.assertEquals(matches[1].confidence, 1.0)
  lu.assertEquals(matches[2].confidence, 1.0)
  local starts = { matches[1].start_index, matches[2].start_index }
  table.sort(starts)
  lu.assertEquals(starts, { 3, 8 })
end

function TestFuzzyAligner:testCommonFirstWordUsesRareAnchor()
  -- "the" appears everywhere; the rare word should anchor the search
  local matches = match_phrase(
    'the obsidian fortress',
    'the one and the other the obsidian fortress the end')
  lu.assertEquals(#matches, 1)
  lu.assertEquals(matches[1].start_index, 6)
  lu.assertEquals(matches[1].end_index, 8)
end

function TestFuzzyAligner:testHyphenatedScriptMatchesSplitTranscript()
  local matches = match_phrase(
    'a well-known secret',
    'this is a well known secret indeed')
  lu.assertEquals(#matches, 1)
  lu.assertEquals(matches[1].confidence, 1.0)
  lu.assertEquals(matches[1].start_index, 3)
  lu.assertEquals(matches[1].end_index, 6)
end

function TestFuzzyAligner:testMinConfidenceOption()
  local matches = match_phrase(
    'seal the ancient gateway forever',
    'we seal the gateway forever now',
    { min_confidence = 0.95 })
  lu.assertEquals(#matches, 0)
end

function TestFuzzyAligner:testBackToBackTakesFoundSeparately()
  -- No separator words at all between the two takes
  local matches = match_phrase(
    'strike the crystal core',
    'strike the crystal core strike the crystal core')
  lu.assertEquals(#matches, 2)
  lu.assertEquals(matches[1].confidence, 1.0)
  lu.assertEquals(matches[2].confidence, 1.0)
end

function TestFuzzyAligner:testMaxMatchesCap()
  local line = 'strike the crystal core'
  local matches = match_phrase(
    line,
    line .. ' and ' .. line .. ' and ' .. line .. ' and ' .. line,
    { max_matches = 2 })
  lu.assertEquals(#matches, 2)
end

function TestFuzzyAligner:testEmptyNeedle()
  local stream = stream_of('some words here')
  lu.assertEquals(FuzzyAligner.find_matches({}, stream), {})
end

function TestFuzzyAligner:testEmptyStream()
  local stream = FuzzyAligner.prepare_stream({})
  lu.assertEquals(FuzzyAligner.find_matches({ 'hello' }, stream), {})
end

function TestFuzzyAligner:testSourceIndicesSurviveTokenSplitting()
  -- Stream word 2 tokenizes into two tokens; indices must still refer
  -- to source word positions
  local stream = FuzzyAligner.prepare_stream({ 'the', 'well-known', 'secret' })
  local matches = FuzzyAligner.find_matches(
    TextNormalizer.tokenize('well known secret'), stream)
  lu.assertEquals(#matches, 1)
  lu.assertEquals(matches[1].start_index, 2)
  lu.assertEquals(matches[1].end_index, 3)
end

--

os.exit(lu.LuaUnit.run())
