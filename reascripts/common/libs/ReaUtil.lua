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

function ReaUtil.disabler(context)
  return function(predicate, f)
    if not predicate then
      f()
      return
    end

    reaper.ImGui_BeginDisabled(context, true)
    f()
    reaper.ImGui_EndDisabled(context)
  end
end