--[[

  Logging.lua - Utilities for generic logging across classes
                (or anything else that's table based, really)

]]--

Logging = {
  LOG_LEVEL_LOG = false,
  LOG_LEVEL_DEBUG = true,

  show_logs = false,
  show_debug_logs = false,

  logs = {},

  _loggers = {
    log = function(prefix, msg)
      Logging.make_log_entry(prefix, msg, Logging.LOG_LEVEL_LOG)
    end,

    debug = function(prefix, msg)
      Logging.make_log_entry(prefix, msg, Logging.LOG_LEVEL_DEBUG)
    end
  }
}

function Logging:react()
  if not self.show_logs then
    self:reset()
    return
  end

  for _, log in pairs(self.logs) do
    local msg, dbg = table.unpack(log)

    if dbg and self.show_debug_logs then
      reaper.ShowConsoleMsg(msg .. '\n')
    elseif not dbg then
      reaper.ShowConsoleMsg(msg .. '\n')
    end
  end

  self:reset()
end

function Logging.init(target, prefix)
  function target:log(msg)
    Logging._loggers.log(prefix, msg)
  end

  function target:debug(msg)
    Logging._loggers.debug(prefix, msg)
  end
end

function Logging.make_log_entry(prefix, msg, is_debug)
  local log_level = is_debug and "DBG" or "LOG"
  local time = Logging.log_time()

  local log_entry = ("%s [%s, %s] %s"):format(time, prefix, log_level, msg)
  table.insert(Logging.logs, { log_entry, is_debug })
end

function Logging.log_time()
  return os.date("%Y-%m-%d %H:%M:%S")
end

function Logging:reset()
  self.logs = {}
end