--[[

  Logging.lua - Utilities for generic logging across classes
                (or anything else that's table based, really)

]]--

Logging = setmetatable({}, {
  __call = function(self)
    if self._instance then
      return self._instance
    end

    self._instance = self._init(self)
    return self._instance
  end
})

Logging._init = function()
  local API = {}
  API = {
    LOG_LEVEL_LOG = false,
    LOG_LEVEL_DEBUG = true,

    show_logs = Storage.memory(false),
    show_debug_logs = Storage.memory(false),

    logs = {},

    _loggers = {
      log = function(prefix, msg)
        API.make_log_entry(prefix, msg, API.LOG_LEVEL_LOG)
      end,

      debug = function(prefix, msg)
        API.make_log_entry(prefix, msg, API.LOG_LEVEL_DEBUG)
      end
    }
  }

  function API:react()
    if not self.show_logs:get() then
      self:reset()
      return
    end

    for _, log in pairs(self.logs) do
      local msg, dbg = table.unpack(log)

      if dbg and self.show_debug_logs:get() then
        reaper.ShowConsoleMsg(msg .. '\n')
      elseif not dbg then
        reaper.ShowConsoleMsg(msg .. '\n')
      end
    end

    self:reset()
  end

  function API.init(target, prefix)
    function target:log(msg)
      API._loggers.log(prefix, msg)
    end

    function target:debug(msg)
      API._loggers.debug(prefix, msg)
    end
  end

  function API.make_log_entry(prefix, msg, is_debug)
    local log_level = is_debug and "DBG" or "LOG"
    local time = API.log_time()

    local log_entry = ("%s [%s, %s] %s"):format(time, prefix, log_level, msg)
    table.insert(API.logs, { log_entry, is_debug })
  end

  function API.log_time()
    return os.date("%Y-%m-%d %H:%M:%S")
  end

  function API:reset()
    if #self.logs > 0 then
      self.logs = {}
    end
  end

  return API
end
