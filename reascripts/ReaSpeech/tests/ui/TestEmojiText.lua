package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('ui/EmojiText')

--

TestEmojiTextParse = {}

function TestEmojiTextParse:setUp()
  EmojiText._parse_cache = {}
end

function TestEmojiTextParse:testPlainText()
  lu.assertEquals(EmojiText.parse('hello world'), { { text = 'hello world' } })
end

function TestEmojiTextParse:testLeadingTag()
  lu.assertEquals(EmojiText.parse(':check: 5 suggestions'), {
    { icon = 'emoji-check' },
    { text = ' 5 suggestions' },
  })
end

function TestEmojiTextParse:testMiddleTag()
  lu.assertEquals(EmojiText.parse('a :warning: b'), {
    { text = 'a ' },
    { icon = 'emoji-warning' },
    { text = ' b' },
  })
end

function TestEmojiTextParse:testAdjacentTags()
  lu.assertEquals(EmojiText.parse(':check::rejected:'), {
    { icon = 'emoji-check' },
    { icon = 'emoji-rejected' },
  })
end

function TestEmojiTextParse:testUnknownTagStaysLiteral()
  lu.assertEquals(EmojiText.parse(':nope: text'), { { text = ':nope: text' } })
end

function TestEmojiTextParse:testUnknownThenKnownOverlap()
  -- ':nope:check:' — the failed ':nope:' must not consume the colon
  -- that opens the valid ':check:'... but here ':check:' shares its
  -- opening colon with ':nope:'s closer, so only the literal remains
  lu.assertEquals(EmojiText.parse(':nope:check: x'), {
    { text = ':nope' },
    { icon = 'emoji-check' },
    { text = ' x' },
  })
end

function TestEmojiTextParse:testTimecodesAreSafe()
  lu.assertEquals(EmojiText.parse(':pin: 1:23:45 - 1:23:59'), {
    { icon = 'emoji-pin' },
    { text = ' 1:23:45 - 1:23:59' },
  })
end

function TestEmojiTextParse:testEmptyString()
  lu.assertEquals(EmojiText.parse(''), {})
end

function TestEmojiTextParse:testMemoized()
  lu.assertIs(EmojiText.parse('a :check: b'), EmojiText.parse('a :check: b'))
end

--

os.exit(lu.LuaUnit.run())
