package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Ctx')
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

function TestWidgets:testSetKeyboardNav()
  local nav_flag = 4
  local other_flags = 16
  local flags = nav_flag | other_flags
  local writes = {}

  ImGui.ConfigVar_Flags = function() return 'flags' end
  ImGui.ConfigFlags_NavEnableKeyboard = function() return nav_flag end
  ImGui.GetConfigVar = function(_ctx, _var) return flags end
  ImGui.SetConfigVar = function(_ctx, _var, value)
    flags = value
    table.insert(writes, value)
  end

  -- already enabled: no redundant write
  Widgets.set_keyboard_nav(true)
  lu.assertEquals(writes, {})

  -- disabling clears only the nav flag
  Widgets.set_keyboard_nav(false)
  lu.assertEquals(flags, other_flags)

  -- re-enabling restores it, unrelated flags intact throughout
  Widgets.set_keyboard_nav(true)
  lu.assertEquals(flags, nav_flag | other_flags)
  lu.assertEquals(#writes, 2)
end

--

os.exit(lu.LuaUnit.run())
