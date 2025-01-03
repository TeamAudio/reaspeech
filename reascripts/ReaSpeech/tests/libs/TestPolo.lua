package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

--

TestPolo = {}

function TestPolo:testClassFields()
  local TestPoloClass = Polo {
    field1 = "this is a field",
    field2 = "this is another field",
  }

  lu.assertEquals(TestPoloClass.field1, "this is a field")
  lu.assertEquals(TestPoloClass.field2, "this is another field")
end

function TestPolo:testDefaultNewMethod()
  local TestPoloClass = Polo {}

  lu.assertNotIsNil(TestPoloClass.new)
end

function TestPolo:testOverriddenNewMethod()
  local TestPoloClass = Polo {
    new = function(field1, field2)
      return {
        field1 = field1,
        field2 = field2,
      }
    end
  }

  local testPolo = TestPoloClass.new("this is a field", "this is another field")

  lu.assertEquals(testPolo.field1, "this is a field")
  lu.assertIsNil(TestPoloClass.field1)
  lu.assertNotEquals(TestPoloClass.field1, "this is a field")
  lu.assertEquals(testPolo.field2, "this is another field")
  lu.assertIsNil(TestPoloClass.field2)
  lu.assertNotEquals(TestPoloClass.field2, "this is another field")
end

function TestPolo:testOptionalInitMethod()
  local TestPoloClass = Polo {
    init = function(self)
      self.field1 = "this is a field"
      self.field2 = "this is another field"
    end
  }

  local testPolo = TestPoloClass.new()

  lu.assertEquals(testPolo.field1, "this is a field")
  lu.assertEquals(testPolo.field2, "this is another field")
end

function TestPolo:testInitMethodDefinedLater()
  local TestPoloClass = Polo {}

  function TestPoloClass:init()
    self.field1 = "this is a field"
    self.field2 = "this is another field"
  end

  local testPolo = TestPoloClass.new()

  lu.assertEquals(testPolo.field1, "this is a field")
  lu.assertEquals(testPolo.field2, "this is another field")
end

function TestPolo:testInstanceMethod()
  local TestPoloClass = Polo {
    instanceMethodDefinedUpFront = function(self)
      return "inside instanceMethodDefinedUpFront"
    end
  }

  function TestPoloClass:instanceMethodDefinedLater()
    return "inside instanceMethodDefinedLater"
  end

  local testPolo = TestPoloClass.new()
  lu.assertEquals(testPolo:instanceMethodDefinedUpFront(), "inside instanceMethodDefinedUpFront")
  lu.assertEquals(testPolo:instanceMethodDefinedLater(), "inside instanceMethodDefinedLater")
end

--

os.exit(lu.LuaUnit.run())
