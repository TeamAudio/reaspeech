reaper = reaper or {
  __ext_state__ = {},

  __test_setUp = function ()
    reaper.__ext_state__ = {}
  end,

  APIExists = function (_)
    return false
  end,

  ColorToNative = function (r, g, b)
    return (math.tointeger(r) or 0) + ((math.tointeger(g) or 0) << 8) + ((math.tointeger(b) or 0) << 16)
  end,

  GetExtState = function (section, key)
    if reaper.__ext_state__[section] then
      return reaper.__ext_state__[section][key]
    end
  end,

  HasExtState = function (section, key)
    return reaper.GetExtState(section, key) ~= nil
  end,

  SetExtState = function (section, key, value)
    if not reaper.__ext_state__[section] then
      reaper.__ext_state__[section] = {}
    end
    reaper.__ext_state__[section][key] = value
  end,

  DeleteExtState = function (section, key)
    if reaper.__ext_state__[section] then
      reaper.__ext_state__[section][key] = nil
    end
  end,

  GetOS = function ()
    return 'Win64'
  end,

  GetAppVersion = function ()
    return '7.07/x64'
  end,

  GetResourcePath = function ()
    return 'tests/resources'
  end,

  MB = print,
  ShowConsoleMsg = print,
  ShowMessageBox = print,

  ImGui_PushStyleColor = function (context, key, value) end,
  ImGui_PopStyleColor = function (context, count) end,

  ImGui_PushStyleVar = function (context, key, ...) end,
  ImGui_PopStyleVar = function (context, count) end,

  defer = function (f)
    f()
  end,

  get_action_context = function ()
    local path = debug.getinfo(2, "S").source:sub(2)
    return false, path
  end,

  ImGui_BeginDisabled = function(context, disabled) end,
  ImGui_EndDisabled = function(context) end,
}

if reaper.__test_setUp then reaper.__test_setUp() end

gfx = gfx or {
  init = function (name, w, h, dock, x, y)
    gfx.__name = name
    gfx.w = w
    gfx.h = h
    gfx.__dock = dock
    gfx.x = x
    gfx.y = y
  end,

  clear = function (_) end,

  clienttoscreen = function (_, _)
    return 0, 0
  end,

  dock = function (_, _, _, _, _)
    return 0, 0, 0, 0, 0
  end,

  measurestr = function (_)
    return 0, 0
  end,

  circle = function (_, _, _, _, _) end,
  drawstr = function (_) end,
  muladdrect = function (_, _, _, _, _, _, _, _, _, _, _, _) end,
  rect = function (_, _, _, _) end,
  roundrect = function (_, _, _, _, _, _, _) end,
  set = function (_, _, _, _) end,
  setfont = function (_, _, _, _) end,
  setimgdim = function (_, _, _) end,
  quit = function () end,
}
