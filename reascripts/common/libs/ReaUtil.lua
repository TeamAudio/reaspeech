--[[

  ReaUtil.lua - Utility functions for Reaper Interaction

]]--

ReaUtil = {}

function ReaUtil.proxy_main_on_command(command_number, flag)
  return function (proj)
    proj = proj or 0
    reaper.Main_OnCommandEx(command_number, flag, proj)
  end
end