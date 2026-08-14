package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('main/script_match/curation/matchers/TextNormalizer')

--

TestTextNormalizer = {}

function TestTextNormalizer:testLowercase()
  lu.assertEquals(TextNormalizer.tokenize('Hello World'), { 'hello', 'world' })
end

function TestTextNormalizer:testStripsPunctuation()
  lu.assertEquals(
    TextNormalizer.tokenize('Wait, what?! (Really...)'),
    { 'wait', 'what', 'really' })
end

function TestTextNormalizer:testKeepsInternalApostrophe()
  lu.assertEquals(TextNormalizer.tokenize("Don't stop"), { "don't", 'stop' })
end

function TestTextNormalizer:testStripsEdgeApostrophes()
  lu.assertEquals(TextNormalizer.tokenize("'tis 'quoted'"), { 'tis', 'quoted' })
end

function TestTextNormalizer:testFoldsCurlyApostrophe()
  lu.assertEquals(TextNormalizer.tokenize('Don\u{2019}t'), { "don't" })
end

function TestTextNormalizer:testFoldsCurlyQuotes()
  lu.assertEquals(
    TextNormalizer.tokenize('\u{201C}Hello\u{201D} she said'),
    { 'hello', 'she', 'said' })
end

function TestTextNormalizer:testSplitsHyphenatedWords()
  lu.assertEquals(TextNormalizer.tokenize('well-known fact'), { 'well', 'known', 'fact' })
end

function TestTextNormalizer:testSplitsEmDash()
  lu.assertEquals(TextNormalizer.tokenize('wait\u{2014}no'), { 'wait', 'no' })
end

function TestTextNormalizer:testEllipsisSeparates()
  lu.assertEquals(TextNormalizer.tokenize('well\u{2026}maybe'), { 'well', 'maybe' })
end

function TestTextNormalizer:testAmpersandBecomesAnd()
  lu.assertEquals(TextNormalizer.tokenize('salt & pepper'), { 'salt', 'and', 'pepper' })
end

function TestTextNormalizer:testAliases()
  lu.assertEquals(TextNormalizer.tokenize('OK, take 2'), { 'okay', 'take', 'two' })
end

function TestTextNormalizer:testPurePunctuationYieldsNothing()
  lu.assertEquals(TextNormalizer.tokenize('-- ... !?'), {})
end

function TestTextNormalizer:testEmptyString()
  lu.assertEquals(TextNormalizer.tokenize(''), {})
end

function TestTextNormalizer:testCollapsesWhitespace()
  lu.assertEquals(TextNormalizer.tokenize('  spaced   out  '), { 'spaced', 'out' })
end

function TestTextNormalizer:testStripsSquareBracketDirections()
  lu.assertEquals(
    TextNormalizer.strip_stage_directions('[Startled yelp.] Cut me some slack'),
    '  Cut me some slack')
end

function TestTextNormalizer:testStripsCurlyBraceDirections()
  lu.assertEquals(
    TextNormalizer.strip_stage_directions('"Friends?" {With a sigh} We were furniture.'),
    '"Friends?"   We were furniture.')
end

function TestTextNormalizer:testStripsParentheticalDirections()
  lu.assertEquals(
    TextNormalizer.strip_stage_directions('Sure (beat) whatever you say'),
    'Sure   whatever you say')
end

function TestTextNormalizer:testUnbalancedBracketLeftAlone()
  lu.assertEquals(
    TextNormalizer.strip_stage_directions('a [ b'),
    'a [ b')
end

function TestTextNormalizer:testDirectionOnlyLineBecomesBlank()
  lu.assertEquals(
    TextNormalizer.tokenize(TextNormalizer.strip_stage_directions('[Gasps.]')),
    {})
end

--

os.exit(lu.LuaUnit.run())
