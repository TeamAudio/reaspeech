package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('ReaUtil')

require('mock_reaper')

reaper.CountTracks = function(_proj)
  return 1
end

reaper.GetTrack = function(_proj, _track_idx)
  return "track"
end

require('ReaIter')

TestReaUtil = {}

function TestReaUtil:setUp()
  reaper.__test_setUp()
end

function TestReaUtil:testProxyMainOnCommand()
  local proxy = ReaUtil.proxy_main_on_command(1, 0)
  lu.assertEquals(type(proxy), "function")
end

function TestReaUtil:testProxyMainOnCommandProjectArgument()
  local proxy = ReaUtil.proxy_main_on_command(1, 0)

  reaper.Main_OnCommandEx = function(_command_number, _flag, proj)
    lu.assertEquals(proj, 0)
  end
  proxy()

  reaper.Main_OnCommandEx = function(_command_number, _flag, proj)
    lu.assertEquals(proj, 1)
  end
  proxy(1)
end

function TestReaUtil:testProxyMainOnCommandCallsMainOnCommandEx()
  local proxy = ReaUtil.proxy_main_on_command(1, 0)

  local main_on_command_ex_called = false

  reaper.Main_OnCommandEx = function(command_number, flag, _proj)
    main_on_command_ex_called = true
    lu.assertEquals(command_number, 1)
    lu.assertEquals(flag, 0)
  end

  proxy()
  lu.assertEquals(main_on_command_ex_called, true)
end

function TestReaUtil:testDisablerReturnsFunction()
  local disabler = ReaUtil.disabler("imgui context")
  lu.assertEquals(type(disabler), "function")
end

function TestReaUtil:testDisablerDefaultErrorHandler()
  local disabler = ReaUtil.disabler("imgui context")

  local default_handler_called = false

  reaper.ShowConsoleMsg = function(_msg)
    default_handler_called = true
  end

  disabler(true, function() error("error") end)
  lu.assertEquals(default_handler_called, true)
end

function TestReaUtil:testDisablerCustomErrorHandler()
  local custom_handler_called = false
  local disabler = ReaUtil.disabler("imgui context", function(msg)
    custom_handler_called = true
    lu.assertEquals(msg, "error")
  end)

  disabler(true, function() error("error") end)
  lu.assertEquals(custom_handler_called, true)
end

function TestReaUtil:testDisablerContext()
  local disabler = ReaUtil.disabler("imgui context")

    reaper.ImGui_BeginDisabled = function(context, _disabled)
      lu.assertEquals(context, "imgui context")
    end

    reaper.ImGui_EndDisabled = function(context)
      lu.assertEquals(context, "imgui context")
    end

    disabler(true, function() end)
end

function TestReaUtil:testDisablerWrapping()
  local disabler = ReaUtil.disabler("imgui context")

  local begin_marker = false
  local function_called_marker = false
  local end_marker = false

  reaper.ImGui_BeginDisabled = function(_context, _disabled)
    begin_marker = true
  end

  local f = function()
    function_called_marker = true
  end

  reaper.ImGui_EndDisabled = function(_context)
    end_marker = true
  end

  disabler(true, f)
  lu.assertEquals(begin_marker, true)
  lu.assertEquals(function_called_marker, true)
  lu.assertEquals(end_marker, true)

  begin_marker = false
  function_called_marker = false
  end_marker = false

  disabler(false, f)
  lu.assertEquals(begin_marker, false)
  lu.assertEquals(function_called_marker, true)
  lu.assertEquals(end_marker, false)
end

function TestReaUtil:testTrackGuids()
  reaper.GetTrackGUID = function(_track)
    return "guid"
  end

  local guids = ReaUtil.track_guids()
  lu.assertEquals(guids[1][1], "guid")
  lu.assertEquals(guids[1][2], "track")
end

function TestReaUtil:testGetItemInfo()
  reaper.GetSetMediaItemInfo_String = function(item, param, _, is_set)
    lu.assertIsFalse(is_set)
    if item == 'item' and param == "GUID" then
      return true, "item_guid"
    end
  end

  lu.assertIsNil(ReaUtil.get_item_info("derp", "GUID"))
  lu.assertEquals(ReaUtil.get_item_info("item", "GUID"), "item_guid")
end

function TestReaUtil:testGetTakeInfo()
  reaper.GetSetMediaItemTakeInfo_String = function(take, param, _, is_set)
    lu.assertIsFalse(is_set)
    if take == 'take' and param == "GUID" then
      return true, "take_guid"
    end
  end

  lu.assertIsNil(ReaUtil.get_take_info("derp", "GUID"))
  lu.assertEquals(ReaUtil.get_take_info("take", "GUID"), "take_guid")
end

function TestReaUtil:testGetObjectInfoDefaults()
  reaper.GetSetMediaItemInfo_String = function(item, param, _, is_set)
    lu.assertIsFalse(is_set)
    if item == 'item' and param == "GUID" then
      return true, "item_guid"
    end
  end

  reaper.GetSetMediaItemTakeInfo_String = function(take, param, _, is_set)
    lu.assertIsFalse(is_set)
    if take == 'take' and param == "GUID" then
      return true, "take_guid"
    end
  end

  lu.assertEquals(ReaUtil.get_item_info('item', 'GUID', 'derpfault'), 'item_guid')
  lu.assertEquals(ReaUtil.get_item_info('duh', 'GUID', 'derpfault'), 'derpfault')
  lu.assertEquals(ReaUtil.get_take_info('take', 'GUID', 'derpfault'), 'take_guid')
  lu.assertEquals(ReaUtil.get_take_info('duh', 'GUID', 'derpfault'), 'derpfault')
end

function TestReaUtil:testGetItemByGUID()
  reaper.CountMediaItems = function() return 2 end
  reaper.GetMediaItem = function(_, idx)
    if idx == 0 then
      return "item1"
    elseif idx == 1 then
      return "item2"
    end
  end

  ReaIter.each_media_item = ReaIter._make_iterator(reaper.CountMediaItems, reaper.GetMediaItem)

  reaper.GetSetMediaItemInfo_String = function(item, param, _, is_set)
    lu.assertIsFalse(is_set)
    if item == 'item1' and param == "GUID" then
      return true, "item1_guid"
    elseif item == 'item2' and param == "GUID" then
      return true, "item2_guid"
    end
  end

  lu.assertEquals(ReaUtil.get_item_by_guid("item1_guid"), "item1")
  lu.assertEquals(ReaUtil.get_item_by_guid("item2_guid"), "item2")
  lu.assertIsNil(ReaUtil.get_item_by_guid("derp"))
end

--

os.exit(lu.LuaUnit.run())
