--[[

  PathUtil.lua - Path utilities for ReaScript

]]--

PathUtil = {}

-- Apply an extension to a file path, if it doesn't already have one.
-- Empty or nil path returns the empty string.
PathUtil.apply_extension = function(filepath, extension)
  if not filepath or #filepath < 1 then
    return ""
  end

  local root, _, ext = filepath:match("([^%.]*)(%.?([^\\/%.]*))")

  if not root or #root < 1 then
    if ext and #ext > 0 then
      return filepath
    end

    return ""
  end

  if #ext > 0 then
    return filepath
  end

  return filepath .. '.' .. extension
end

-- Returns the given path if a full path, otherwise returns given path
-- relative to the REAPER project resource directory.
PathUtil.get_real_path = function(path_arg)
  if PathUtil._is_full_path(path_arg) then
    return path_arg
  end

  local project_path = reaper.GetProjectPath()
  return project_path .. PathUtil._path_separator() .. path_arg
end

-- Returns the command to reveal the given path in the OS file explorer.
-- Works for Windows and macOS. To quote a wise philosopher, "Linux is a mess."
PathUtil.get_reveal_command = function(path_arg)
  if EnvUtil.is_windows() then
    return '%SystemRoot%\\explorer.exe /select,"' .. path_arg .. '"'
  elseif EnvUtil.is_mac() then
    return '/bin/[ -x /usr/bin/open ] && /usr/bin/open -R "' .. path_arg .. '"'
  else
    return '/bin/[ -x /usr/bin/xdg-open ] && /usr/bin/xdg-open "' .. path_arg .. '"'
  end
end

PathUtil._is_full_path = function(path)
  local found

  if EnvUtil.is_windows() then
    found = path:find("^%w:\\") or path:find("^\\")
  else
    found = path:find("^/")
  end

  return found and true or false
end

PathUtil._path_separator = function()
  if EnvUtil.is_windows() then
    return "\\"
  else
    return "/"
  end
end
