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
  -- that closes it, because that same colon opens the valid ':check:':
  -- the literal keeps ':nope' and the icon still matches
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

TestEmojiTextRender = {}

function TestEmojiTextRender:setUp()
  EmojiText._parse_cache = {}

  self._ctx = Ctx
  self._imgui = ImGui
  self._images = IMAGES

  Ctx = function() return 'ctx' end

  self.events = {}
  local events = self.events

  ImGui = {
    Text = function(_, text) table.insert(events, 'text:' .. text) end,
    TextColored = function(_, color, text)
      table.insert(events, ('colored:%x:%s'):format(color, text))
    end,
    SameLine = function() table.insert(events, 'sameline') end,
    Dummy = function() table.insert(events, 'dummy') end,
    GetTextLineHeight = function() return 10 end,
    GetCursorScreenPos = function() return 0, 0 end,
    ValidatePtr = function(ptr) return ptr ~= nil end,
    CreateImageFromMem = function()
      table.insert(events, 'create-image')
      return 'image'
    end,
    GetWindowDrawList = function() return 'drawlist' end,
    DrawList_AddImage = function() table.insert(events, 'draw-image') end,
    CalcTextSize = function(_, text) return #text * 7 end,
  }

  IMAGES = { ['emoji-check'] = { bytes = 'png-bytes' } }
end

function TestEmojiTextRender:tearDown()
  Ctx = self._ctx
  ImGui = self._imgui
  IMAGES = self._images
end

function TestEmojiTextRender:testRenderMixedRuns()
  EmojiText.render(':check: done')

  lu.assertEquals(self.events,
    { 'create-image', 'dummy', 'draw-image', 'sameline', 'text: done' })
end

function TestEmojiTextRender:testRenderColorsTextRunsOnly()
  EmojiText.render('ok :check:', 0xff0000ff)

  lu.assertEquals(self.events,
    { 'colored:ff0000ff:ok ', 'sameline', 'create-image', 'dummy', 'draw-image' })
end

function TestEmojiTextRender:testCreatedImageIsReused()
  EmojiText.render(':check:')
  EmojiText.render(':check:')

  lu.assertEquals(self.events,
    { 'create-image', 'dummy', 'draw-image', 'dummy', 'draw-image' })
end

function TestEmojiTextRender:testMissingImageReservesSlot()
  IMAGES['emoji-check'] = nil

  EmojiText.render(':check:')

  lu.assertEquals(self.events, { 'dummy' })
end

function TestEmojiTextRender:testPlainTextSingleCall()
  EmojiText.render('no tags here')

  lu.assertEquals(self.events, { 'text:no tags here' })
end

function TestEmojiTextRender:testCalcWidth()
  -- icon at line height (10) plus text at 7 per char
  lu.assertEquals(EmojiText.calc_width(':check: ab'), 10 + 3 * 7)
  -- an explicit slot size overrides the icon width
  lu.assertEquals(EmojiText.calc_width(':check: ab', 16), 16 + 3 * 7)
  lu.assertEquals(EmojiText.calc_width('abcd'), 4 * 7)
end

os.exit(lu.LuaUnit.run())
