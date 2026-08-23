package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/StringUtils')

--

TestStringUtils = {}

function TestStringUtils:testSplitMethodExists()
  lu.assertNotNil(string['split'])
  lu.assertEquals(type(string['split']), 'function')
end

function TestStringUtils:testSplit()
  local expectations = {
    [{'oh,hello,there', ','}] = {'oh', 'hello', 'there'},
    [{'oh, hello, there', ','}] = {'oh', ' hello', ' there'},
    [{',oh, hello, there ,', ','}] = {'', 'oh', ' hello', ' there ', ''},
    [{'oh,hello,there', ';'}] = {'oh,hello,there'},
    [{'oh;hello;there', ';'}] = {'oh', 'hello', 'there'},
  }

  for input, expected in pairs(expectations) do
    local result = input[1]:split(input[2])
    lu.assertEquals(result, expected)
  end
end

TestBase64 = {}

function TestBase64:testRoundTripsAllPaddingLengths()
  for _, input in ipairs({ '', 'a', 'ab', 'abc', 'abcd', 'Hello, world!', '{"v":1}' }) do
    lu.assertEquals(input:base64_encode():base64_decode(), input)
  end
end

function TestBase64:testKnownVector()
  lu.assertEquals(('Man'):base64_encode(), 'TWFu')
  lu.assertEquals(('Ma'):base64_encode(), 'TWE=')
  lu.assertEquals(('M'):base64_encode(), 'TQ==')
end

function TestBase64:testBinaryBytes()
  local bytes = string.char(0, 255, 16, 128, 7)
  lu.assertEquals(bytes:base64_encode():base64_decode(), bytes)
end

function TestBase64:testDecodeRejectsGarbage()
  lu.assertNil(('!!!!'):base64_decode())
  lu.assertNil(('abc'):base64_decode()) -- bad length
end

function TestBase64:testDecodeRejectsInvalidPadding()
  lu.assertNil(('===='):base64_decode())
  lu.assertNil(('T==='):base64_decode())
  lu.assertNil(('=TQ='):base64_decode())
  lu.assertNil(('TQ==TQ=='):base64_decode()) -- padding before the final block
end

os.exit(lu.LuaUnit.run())
