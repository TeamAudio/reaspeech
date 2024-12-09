--[[

  EnvUtil.lua - utilities for querying REAPER environment

]]--

EnvUtil = {}

EnvUtil.is_windows = function()
  return EnvUtil._bool(reaper.GetOS():find('Win', 1, true))
end

EnvUtil.is_mac = function()
  local is_mac = reaper.GetOS():find('OSX', 1, true)
    or reaper.GetOS():find('macOS', 1, true)

  return EnvUtil._bool(is_mac)
end

EnvUtil.is_linux = function()
  return EnvUtil._bool(reaper.GetOS():find('Other', 1, true))
end

EnvUtil._bool = function(val) return val and true or false end