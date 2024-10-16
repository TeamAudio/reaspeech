--[[

  ExecProcess.lua - wrapper for process execution in REAPER

]]--

ExecProcess = {
  WAIT_FOREVER = 0,
  NO_WAIT = -1,
  BACKGROUND = -2,

  new = function(command)
    local o = { command = command }
    setmetatable(o, ExecProcess)
    return o
  end
}
ExecProcess.__index = ExecProcess

function ExecProcess:run(timeout)
  return reaper.ExecProcess(self.command, timeout)
end

function ExecProcess:wait(timeout)
  return self:run(timeout or self.WAIT_FOREVER)
end

function ExecProcess:no_wait()
  return self:run(self.NO_WAIT)
end

function ExecProcess:background()
  return self:run(self.BACKGROUND)
end
