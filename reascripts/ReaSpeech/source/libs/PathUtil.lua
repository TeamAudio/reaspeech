--[[

  PathUtil.lua - Path utilities for ReaScript

]]--

PathUtil = {}

-- Returns true if the given file path has an extension, false otherwise.
PathUtil.has_extension = function(filepath, extension)
  local pattern

  if extension then
    pattern = "%." .. extension .. "$"
  else
    pattern = "%.[^%.\\/%s]*$"
  end

  return filepath:find(pattern) and true or false
end

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

-- Returns the filename+extension portion of a full path.
PathUtil.get_filename = function(filepath)
  return filepath:match("[^\\/]*$")
end

-- Returns the given path if a full path, otherwise returns given path
-- relative to the REAPER project resource directory.
PathUtil.get_real_path = function(path_arg)
  if PathUtil.is_full_path(path_arg) then
    return path_arg
  end

  local project_path = reaper.GetProjectPath()
  return PathUtil.normalize(project_path .. PathUtil._path_separator() .. path_arg)
end

-- Returns the command to reveal the given path in the OS file explorer.
-- Works for Windows and macOS. To quote a wise philosopher, "Linux is a mess."
PathUtil.get_reveal_command = function(path_arg)
  if EnvUtil.is_windows() then
    return '%SystemRoot%\\explorer.exe /select,"' .. path_arg .. '"'
  elseif EnvUtil.is_mac() then
    return '/usr/bin/env open -R "' .. path_arg .. '"'
  else
    return '/usr/bin/env xdg-open "' .. path_arg .. '"'
  end
end

-- Returns the command to open the given directory in the OS file explorer.
PathUtil.get_open_folder_command = function(path_arg)
  if EnvUtil.is_windows() then
    return '%SystemRoot%\\explorer.exe "' .. path_arg .. '"'
  elseif EnvUtil.is_mac() then
    return '/usr/bin/env open "' .. path_arg .. '"'
  else
    return '/usr/bin/env xdg-open "' .. path_arg .. '"'
  end
end

-- Normalize separators and redundant "." segments in a path.
-- Windows-authored projects can carry backslash record paths (e.g.
-- ".\Media") into REAPER's project-path APIs; on macOS/Linux the
-- backslash would otherwise be treated as part of the file name.
PathUtil.normalize = function(path)
  if not EnvUtil.is_windows() then
    path = path:gsub("\\", "/")
  end

  local previous
  repeat
    previous = path
    path = path:gsub("([/\\])%.[/\\]", "%1")
  until path == previous

  return (path:gsub("[/\\]%.$", ""))
end

-- Returns true if the given path is a full path, false otherwise.
PathUtil.is_full_path = function(path)
  local found

  if EnvUtil.is_windows() then
    found = path:find("^%w:\\") or path:find("^\\")
  else
    found = path:find("^/")
  end

  return found and true or false
end

-- Joins an arbitrary list of path components into a single path
-- using the appropriate path separator for the current OS
-- (as reported by REAPER, anyway).
PathUtil.join = function(...)
  local args = {...}
  local separator = PathUtil._path_separator()

  return table.concat(args, separator)
end

PathUtil._path_separator = function()
  if EnvUtil.is_windows() then
    return "\\"
  else
    return "/"
  end
end
