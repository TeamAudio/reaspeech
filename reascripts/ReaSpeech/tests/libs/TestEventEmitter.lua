package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')
require('libs/Trap')

require('libs/EventEmitter')

--

TestEventEmitter = {}

function TestEventEmitter:setUp()
  Trap.on_error = function() end

  self.emitter = EventEmitter.new {
    schema = {
      thing_happened = { required = { 'thing_id' } },
      loose_event = {},
    }
  }
end

function TestEventEmitter:testEmitReachesListeners()
  local received = {}
  self.emitter:listen('thing_happened', function(event)
    table.insert(received, event.thing_id)
  end)
  self.emitter:listen('thing_happened', function(event)
    table.insert(received, event.thing_id .. '-second')
  end)

  self.emitter:emit('thing_happened', { thing_id = 'abc' })

  lu.assertEquals(received, { 'abc', 'abc-second' })
end

function TestEventEmitter:testEmitWithoutPayloadOnLooseEvent()
  local called = false
  self.emitter:listen('loose_event', function() called = true end)

  self.emitter:emit('loose_event')

  lu.assertTrue(called)
end

function TestEventEmitter:testEmitUndeclaredEventRaises()
  lu.assertErrorMsgContains("undeclared event 'nope'", function()
    self.emitter:emit('nope', {})
  end)
end

function TestEventEmitter:testListenUndeclaredEventRaises()
  lu.assertErrorMsgContains("undeclared event 'nope'", function()
    self.emitter:listen('nope', function() end)
  end)
end

function TestEventEmitter:testMissingRequiredFieldRaises()
  lu.assertErrorMsgContains("missing required field 'thing_id'", function()
    self.emitter:emit('thing_happened', { other = 1 })
  end)
end

function TestEventEmitter:testListenerErrorDoesNotStopEmit()
  local received = false
  self.emitter:listen('thing_happened', function() error('boom') end)
  self.emitter:listen('thing_happened', function() received = true end)

  self.emitter:emit('thing_happened', { thing_id = 'abc' })

  lu.assertTrue(received)
end

function TestEventEmitter:testRemoveListener()
  local count = 0
  local listener = function() count = count + 1 end
  self.emitter:listen('thing_happened', listener)

  self.emitter:emit('thing_happened', { thing_id = 'abc' })
  self.emitter:remove_listener('thing_happened', listener)
  self.emitter:emit('thing_happened', { thing_id = 'abc' })

  lu.assertEquals(count, 1)
end

function TestEventEmitter:testListenerCount()
  lu.assertEquals(self.emitter:listener_count('thing_happened'), 0)
  self.emitter:listen('thing_happened', function() end)
  lu.assertEquals(self.emitter:listener_count('thing_happened'), 1)
end

--

os.exit(lu.LuaUnit.run())
