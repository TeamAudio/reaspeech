--[[

  ReaUtil.lua - Utility functions for Reaper Interaction

]]--

ReaUtil = {
  ACTIVE_PROJECT = 0
}

function ReaUtil.proxy_main_on_command(command_number, flag)
  return function (proj)
    proj = proj or 0
    reaper.Main_OnCommandEx(command_number, flag, proj)
  end
end

function ReaUtil.url_opener(url)
  return function()
    ReaUtil.open_url(url)
  end
end

function ReaUtil.open_url(url)
  local url_opener_cmd
  if reaper.GetOS():match('Win') then
    url_opener_cmd = 'start "" "%s"'
  else
    url_opener_cmd = '/usr/bin/open "%s"'
  end

  (ExecProcess.new(url_opener_cmd:format(url))):wait()
end

function ReaUtil.disabler(context, error_handler)
  error_handler = error_handler or function(msg)
    reaper.ShowConsoleMsg(msg .. '\n')
  end

  return function(predicate, f)
    local safe_f = function()
      xpcall(f, error_handler)
    end

    if not predicate then
      safe_f()
      return
    end

    reaper.ImGui_BeginDisabled(context, true)
    safe_f()
    reaper.ImGui_EndDisabled(context)
  end
end
