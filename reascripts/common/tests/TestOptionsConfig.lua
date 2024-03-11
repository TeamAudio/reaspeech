package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('mock_reaper')
require('OptionsConfig')

--

TestOptionsConfig = {
  options = OptionsConfig:new {
    section = 'ReaSpeech.Options',
    options = {
      patties_per_burger = {'number', 2},
      num_pickles = {'number', 2},
    }
  }
}

function TestOptionsConfig:setUp()
  reaper.__test_setUp()
  reaper.__ext_state__[self.options.section] = {}
end

function TestOptionsConfig:testDefault()
  local num_iterations = self.options:get('num_iterations')
  lu.assertEquals(num_iterations, 2)
end

function TestOptionsConfig:testGet()
  reaper.__ext_state__[self.options.section].num_iterations = '3'
  local num_iterations = self.options:get('num_iterations')
  lu.assertEquals(num_iterations, 3)
  lu.assertEquals(reaper.__ext_state__[self.options.section].num_iterations, '3')
end

function TestOptionsConfig:testSet()
  self.options:set('num_iterations', 4)
  lu.assertEquals(self.options:get('num_iterations'), 4)
  lu.assertEquals(reaper.__ext_state__[self.options.section].num_iterations, '4')
end

function TestOptionsConfig:testDelete()
  self.options:set('num_iterations', 4)
  self.options:delete('num_iterations')
  lu.assertNil(reaper.__ext_state__[self.options.section].num_iterations)
end

function TestOptionsConfig:testExists()
  lu.assertFalse(self.options:exists('num_iterations'))
  self.options:set('num_iterations', 4)
  lu.assertTrue(self.options:exists('num_iterations'))
  self.options:delete('num_iterations')
  lu.assertFalse(self.options:exists('num_iterations'))
end

function TestOptionsConfig:testToString()
  lu.assertEquals(self.options:_number_to_string(42), '42')
  lu.assertEquals(self.options:_number_to_string('x'), '0')
  lu.assertEquals(self.options:_boolean_to_string(true), 'true')
  lu.assertEquals(self.options:_boolean_to_string(false), 'false')
  lu.assertEquals(self.options:_boolean_to_string('x'), 'true')
  lu.assertEquals(self.options:_boolean_to_string(nil), 'false')
end

function TestOptionsConfig:testFromString()
  lu.assertEquals(self.options:_string_to_number('42'), 42)
  lu.assertEquals(self.options:_string_to_number('x'), 0)
  lu.assertTrue(self.options:_string_to_boolean('true'))
  lu.assertFalse(self.options:_string_to_boolean('false'))
  lu.assertFalse(self.options:_string_to_boolean('x'))
  lu.assertFalse(self.options:_string_to_boolean(nil))
end

--

os.exit(lu.LuaUnit.run())
