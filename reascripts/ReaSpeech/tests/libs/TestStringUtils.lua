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

os.exit(lu.LuaUnit.run())
