package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('ReaUtil')

require('mock_reaper')

TestReaUtil = {}

function TestReaUtil:setUp()
  reaper.__test_setUp()
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

--

os.exit(lu.LuaUnit.run())
