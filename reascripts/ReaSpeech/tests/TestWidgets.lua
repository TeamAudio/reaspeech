package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Trap')
require('ui/Widgets')

--

TestWidgets = {}

function TestWidgets:testDisablerWrapping()
  local begin_marker = false
  local function_called_marker = false
  local end_marker = false

  ImGui.BeginDisabled = function(_context, _disabled)
    begin_marker = true
  end

  local f = function()
    function_called_marker = true
  end

  ImGui.EndDisabled = function(_context)
    end_marker = true
  end

  Widgets.disable_if(true, f)
  lu.assertEquals(begin_marker, true)
  lu.assertEquals(function_called_marker, true)
  lu.assertEquals(end_marker, true)

  begin_marker = false
  function_called_marker = false
  end_marker = false

  Widgets.disable_if(false, f)
  lu.assertEquals(begin_marker, false)
  lu.assertEquals(function_called_marker, true)
  lu.assertEquals(end_marker, false)
end

--

os.exit(lu.LuaUnit.run())
