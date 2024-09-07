package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('source/Logging')
require('Polo')

--

TestLogging = {}

function TestLogging:setUp()
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
