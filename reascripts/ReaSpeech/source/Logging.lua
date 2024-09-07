--[[

  Logging.lua - Utilities for generic logging across classes
                (or anything else that's table based, really)

]]--

Logging = {
  _loggers = {
    log = function()
    end,

    debug = function()
    end
  }
}

function Logging.init(target, prefix)
  function target:log(msg)
    Logging._loggers.log(prefix, msg)
  end

  function target:debug(msg)
    Logging._loggers.debug(prefix, msg)
  end
end