package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('mock_reaper')
require('Polo')
require('source/Logging')

--

TestLogging = {}

function TestLogging:setUp()
end

function TestLogging:testLogMethod()
  local prefix = "TestLoggingClass prefix"
  local test_class = Polo {
    init = function(self)
      Logging.init(self, prefix)
    end
  }

  Logging.log_time = function()
    return "<time>"
  end

  Logging.logs = {}

  local log_message1 = "This is a log message"
  local log_message2 = "This is another log message"

  local instance = test_class.new()
  instance:log(log_message1)
  instance:log(log_message2)

  lu.assertEquals(Logging.logs, {
    { ("<time> [%s, LOG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_LOG },
    { ("<time> [%s, LOG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_LOG },
  })
end

function TestLogging:testDebugMethod()
  local prefix = "TestLoggingClass prefix"
  local test_class = Polo {
    init = function(self)
      Logging.init(self, prefix)
    end
  }

  Logging.log_time = function()
    return "<time>"
  end

  Logging.logs = {}

  local log_message1 = "This is a log message"
  local log_message2 = "This is another log message"

  local instance = test_class.new()
  instance:debug(log_message1)
  instance:debug(log_message2)

  lu.assertEquals(Logging.logs, {
    { ("<time> [%s, DBG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_DEBUG },
    { ("<time> [%s, DBG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_DEBUG },
  })
end

function TestLogging:testMixedCalls()
  local prefix = "TestLoggingClass prefix"
  local test_class = Polo {
    init = function(self)
      Logging.init(self, prefix)
    end
  }

  Logging.log_time = function()
    return "<time>"
  end

  Logging.logs = {}

  local log_message1 = "This is a log message"
  local log_message2 = "This is another log message"
  local log_message3 = "This is the third log message"

  local instance = test_class.new()
  instance:log(log_message1)
  instance:debug(log_message2)
  instance:log(log_message3)

  lu.assertEquals(Logging.logs, {
    { ("<time> [%s, LOG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_LOG },
    { ("<time> [%s, DBG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_DEBUG },
    { ("<time> [%s, LOG] %s"):format(prefix, log_message3), Logging.LOG_LEVEL_LOG },
  })
end

function TestLogging:testReset()
  Logging.logs = { "This is a log message", "This is another log message" }

  Logging:reset()

  lu.assertEquals(#Logging.logs, 0)
end

function TestLogging:testResetReusesEmptyLogsTable()
  local original_table = Logging.logs

  Logging:reset()

  lu.assertIs(Logging.logs, original_table)

  Logging.logs = {{ "msg", Logging.LOG_LEVEL_LOG }}

  Logging:reset()

  lu.assertNotIs(Logging.logs, original_table)
end

function TestLogging:testPatchedLogMethod()
  local test_class = Polo {
    init = function(self)
      Logging.init(self, "TestLoggingClass prefix")
    end
  }

  local log_message = "This is a log message"

  Logging._loggers = {
    log = function(prefix, msg)
      lu.assertEquals(prefix, "TestLoggingClass prefix")
      lu.assertEquals(msg, log_message)
    end,
  }

  local instance = test_class.new()
  instance:log(log_message)
end

function TestLogging:testPatchedDebugMethod()
  local test_class = Polo {
    init = function(self)
      Logging.init(self, "TestLoggingClass prefix")
    end
  }

  local debug_message = "This is a debug message"

  Logging._loggers = {
    debug = function(prefix, msg)
      lu.assertEquals(prefix, "TestLoggingClass prefix")
      lu.assertEquals(msg, debug_message)
    end,
  }

  local instance = test_class.new()
  instance:debug(debug_message)
end

function TestLogging:testReactRespectsShowLogsOff()
  Logging.show_logs = false
  Logging.logs = {
    { "This is a log message", Logging.LOG_LEVEL_LOG },
    { "This is a debug message", Logging.LOG_LEVEL_DEBUG },
  }

  local yay_no_calls = true

  reaper.ShowConsoleMsg = function(msg)
      yay_no_calls = false
  end

  Logging:react()

  lu.assertEquals(yay_no_calls, true)
  lu.assertEquals(Logging.logs, {})
end

function TestLogging:testReactRespectsShowLogsOn()
  Logging.show_logs = true
  Logging.show_debug_logs = false

  Logging.logs = {
    { "This is a log message", Logging.LOG_LEVEL_LOG },
    { "This is a debug message", Logging.LOG_LEVEL_DEBUG },
  }

  local happy_call = false
  reaper.ShowConsoleMsg = function(msg)
    if msg:match("This is a log message\n") then
      happy_call = true
    end

    if msg:match("This is a debug message\n") then
      lu.fail("I didn't want debug messages!")
    end
  end

  Logging:react()

  lu.assertEquals(happy_call, true)
  lu.assertEquals(Logging.logs, {})
end

function TestLogging:testReactRespectsShowDebugLogsOn()
  Logging.show_logs = true
  Logging.show_debug_logs = true
  Logging.logs = {
    { "This is a log message", Logging.LOG_LEVEL_LOG },
    { "This is a debug message", Logging.LOG_LEVEL_DEBUG },
  }

  local happy_calls = 0

  reaper.ShowConsoleMsg = function(msg)
    happy_calls = happy_calls + 1
  end

  Logging:react()

  lu.assertEquals(happy_calls, 2)
  lu.assertEquals(Logging.logs, {})
end

function TestLogging:testReactIgnoresShowDebugLogsIfShowLogsOff()
  Logging.show_logs = false
  Logging.show_debug_logs = true
  Logging.logs = {
    { "This is a log message", Logging.LOG_LEVEL_LOG },
    { "This is a debug message", Logging.LOG_LEVEL_DEBUG },
  }

  local sad_calls = 0

  reaper.ShowConsoleMsg = function(msg)
    sad_calls = sad_calls + 1
  end

  Logging:react()

  lu.assertEquals(sad_calls, 0)
  lu.assertEquals(Logging.logs, {})
end

--

os.exit(lu.LuaUnit.run())
