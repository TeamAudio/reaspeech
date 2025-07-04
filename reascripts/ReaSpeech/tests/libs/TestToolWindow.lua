package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Ctx')
require('libs/ImGuiTheme')
require('libs/Logging')
require('libs/Polo')
require('libs/Storage')
require('libs/ToolWindow')
require('libs/Trap')

require('ui/Tween')

--

TestToolWindow = {
  _test_class = function()
    return Polo {
      init = function(self)
        ToolWindow.init(self, {
          title = 'Test Tool Window',
          width = 300,
          height = 200,
          window_flags = 21,
        })
      end
    }
  end
}

function TestToolWindow:setUp()
end

function TestToolWindow:testInit()
  local test_class = self._test_class()

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(type(o._tool_window), 'table')
  lu.assertEquals(o._tool_window.title, 'Test Tool Window')
  lu.assertEquals(o._tool_window.window_flags, 21)
  lu.assertEquals(o._tool_window.width, 300)
  lu.assertEquals(o._tool_window.height, 200)
  lu.assertEquals(type(o:is_open()), 'boolean')
  lu.assertEquals(type(o.open), 'function')
  lu.assertEquals(type(o.close), 'function')
  lu.assertEquals(type(o.render_separator), 'function')
  lu.assertEquals(type(o.render), 'function')
end

function TestToolWindow:testModal()
  local test_class = Polo {
    init = function(self)
      ToolWindow.modal(self, {
        title = 'Test Tool Window',
        width = 300,
        height = 200,
        window_flags = 21,
      })
    end
  }

  ImGui = ImGui or {}
  ImGui.WindowFlags_AlwaysAutoResize = function() return 0 end
  ImGui.WindowFlags_NoCollapse = function() return 1 end
  ImGui.WindowFlags_NoDocking = function() return 2 end

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o._tool_window.is_modal, true)
  lu.assertEquals(type(o._tool_window), 'table')
  lu.assertEquals(o._tool_window.title, 'Test Tool Window')
  lu.assertEquals(o._tool_window.window_flags, 21)
  lu.assertEquals(o._tool_window.width, 300)
  lu.assertEquals(o._tool_window.height, 200)
end

function TestToolWindow:testPresentAndPresenting()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o:presenting(), false)
  o:present()
  lu.assertEquals(o:presenting(), true)
  o:close()
  lu.assertEquals(o:closing(), true)
  o._tool_window.closing = false
  o:close()
  lu.assertEquals(o:presenting(), false)
end

function TestToolWindow:testIsOpen()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o:is_open(), false)
  o:open()
  lu.assertEquals(o:is_open(), true)
  o:close()
  lu.assertEquals(o:closing(), true)
  o._tool_window.closing = false
  o:close()
  lu.assertEquals(o:is_open(), false)
end

function TestToolWindow:testOpen()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  ImGui = ImGui or {}
  ImGui.WindowFlags_AlwaysAutoResize = function() return 0 end
  ImGui.WindowFlags_NoCollapse = function() return 1 end
  ImGui.WindowFlags_NoDocking = function() return 2 end

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o:is_open(), false)
  o:open()
  lu.assertEquals(o:is_open(), true)
end

function TestToolWindow:testWrapOpen()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local wrapped_open_called = false
  function test_class:open()
    wrapped_open_called = true
  end

  local o = test_class.new()
  o:open()
  lu.assertEquals(o:is_open(), true)
  lu.assertEquals(wrapped_open_called, true)
end

function TestToolWindow:testWrapClose()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local wrapped_close_called = false
  function test_class:close()
    wrapped_close_called = true
  end

  local o = test_class.new()
  o:open()
  o:close()
  lu.assertEquals(o:closing(), true)
  o._tool_window.closing = false
  o:close()
  lu.assertEquals(o:is_open(), false)
  lu.assertEquals(wrapped_close_called, true)
end

function TestToolWindow:testClose()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  ImGui = ImGui or {}
  ImGui.WindowFlags_AlwaysAutoResize = function() return 0 end
  ImGui.WindowFlags_NoCollapse = function() return 1 end
  ImGui.WindowFlags_NoDocking = function() return 2 end

  local o = test_class.new()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o:is_open(), false)
  o:open()
  lu.assertEquals(o:is_open(), true)
  o:close()
  lu.assertEquals(o:closing(), true)
  o._tool_window.closing = false
  o:close()
  lu.assertEquals(o:is_open(), false)
end

function TestToolWindow:testRender()
  ImGui = ImGui or {}
  local old_imgui = ImGui

  ImGui = {}

  -- visible, open
  ImGui.Begin = function(_, _, _, _) return true, true end

  ImGui.Cond_Appearing = function() return 1 end
  ImGui.Cond_FirstUseEver = function() return 2 end
  ImGui.End = function(_) end
  ImGui.GetWindowViewport = function() end
  ImGui.SetNextWindowFocus = function(_) end
  ImGui.SetNextWindowPos = function(_, _, _, _, _, _) end
  ImGui.SetNextWindowSize = function(_, _, _, _) end
  ImGui.ValidatePtr = function(_, _) return true end
  ImGui.Viewport_GetCenter = function() return 0, 0 end
  ImGui.WindowFlags_AlwaysAutoResize = function() return 0 end
  ImGui.WindowFlags_NoCollapse = function() return 1 end
  ImGui.WindowFlags_NoDocking = function() return 2 end


  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local render_content_called = false

  function test_class:render_content()
    render_content_called = true
  end

  local o = test_class.new()
  o:render()
  lu.assertNotNil(o._tool_window)
  lu.assertEquals(o:is_open(), false)
  lu.assertEquals(render_content_called, false)

  o:open()
  o:render()
  lu.assertEquals(o:is_open(), true)
  lu.assertEquals(render_content_called, true)

  render_content_called = false
  o:close()
  lu.assertEquals(o:closing(), true)
  o._tool_window.closing = false
  o:close()
  o:render()
  lu.assertEquals(o:is_open(), false)
  lu.assertEquals(render_content_called, false)

  ImGui.Begin = function(_, _, _, _) return false end

  o:render()
  lu.assertEquals(o:is_open(), false)
  lu.assertEquals(render_content_called, false)

  ImGui = old_imgui
end

function TestToolWindow:testRenderSeparator()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  lu.assertEquals(type(test_class.new().render_separator), 'function')
end

--

os.exit(lu.LuaUnit.run())
