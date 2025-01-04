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
  if EnvUtil.is_windows() then
    url_opener_cmd = 'start "" "%s"'
  else
    url_opener_cmd = '/usr/bin/env open "%s"'
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

function ReaUtil.track_guids()
  local guids = {}

  for track in ReaIter.each_track() do
    table.insert(guids, { reaper.GetTrackGUID(track), track })
  end

  return guids
end

function ReaUtil.get_source_path(take)
  local source = reaper.GetMediaItemTake_Source(take)
  if source then
    local source_path = reaper.GetMediaSourceFileName(source)
    return source_path
  end
  return nil
end

function ReaUtil._get_object_info(getter_f, object, param)
  local result, value = getter_f(object, param, '', false)

  return result and value or nil
end

function ReaUtil.get_item_info(item, param, default)
  return ReaUtil._get_object_info(reaper.GetSetMediaItemInfo_String, item, param)
    or default
end

function ReaUtil.get_take_info(take, param, default)
  return ReaUtil._get_object_info(reaper.GetSetMediaItemTakeInfo_String, take, param)
    or default
end

function ReaUtil.get_item_by_guid(guid)
  for item in ReaIter.each_media_item() do
    if ReaUtil.get_item_info(item, 'GUID') == guid then
      return item
    end
  end
  return nil
end