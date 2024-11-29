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
  end,

  via_tempfile = function(command)
    local ep = ExecProcess.new(command)

    function ep:run(timeout)
      local tempfile = Tempfile:name()

      local f = io.open(tempfile, "w")
      if not f then
        return nil, "Unable to open tempfile"
      end

      f:write(ep.command)
      f:close()

      if EnvUtil.is_windows() then
        ep.command = 'cmd /c "' .. tempfile .. '"'
      else
        ep.command = '/bin/bash ' .. tempfile
      end

      local result = ExecProcess.run(ep, timeout)

      --     TODO: is this safe?      --
      -- how temp can a temp file be? --
      --     more testing needed      --
      Tempfile:remove(tempfile)

      return result
    end

    return ep
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
