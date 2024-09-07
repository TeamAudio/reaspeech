package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('source/Logging')
require('Polo')

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
    { ("[<time> %s, LOG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_LOG },
    { ("[<time> %s, LOG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_LOG },
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
    { ("[<time> %s, DBG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_DEBUG },
    { ("[<time> %s, DBG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_DEBUG },
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
    { ("[<time> %s, LOG] %s"):format(prefix, log_message1), Logging.LOG_LEVEL_LOG },
    { ("[<time> %s, DBG] %s"):format(prefix, log_message2), Logging.LOG_LEVEL_DEBUG },
    { ("[<time> %s, LOG] %s"):format(prefix, log_message3), Logging.LOG_LEVEL_LOG },
  })
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

--

os.exit(lu.LuaUnit.run())
