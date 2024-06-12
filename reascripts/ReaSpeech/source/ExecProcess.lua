--[[

  ExecProcess.lua - wrapper for process execution in REAPER

]]--

ExecProcess = Polo {
  WAIT_FOREVER = 0,
  NO_WAIT = -1,
  BACKGROUND = -2,

  new = function(command_string_list)
    return {
      commands = command_string_list
    }
  end
}

ExecProcess.command_prefix = function()
  if reaper.GetOS():match('Win') then
    return 'cmd /c '
  end

  return ''
end

ExecProcess.command_separator = function()
  if reaper.GetOS():match('Win') then
    return ' & '
  end

  return ' ; '
end

function ExecProcess:run(timeout)
  local command_prefix = self.command_prefix()
  local compound_command = command_prefix .. table.concat(self.commands, self.command_separator())

  return reaper.ExecProcess(compound_command, timeout)
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