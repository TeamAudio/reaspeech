package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('mock_reaper')
require('Polo')
require('libs/ToolWindow')
require('source/Logging')
require('source/include/globals')

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
  lu.assertEquals(type(o._tool_window.is_open), 'boolean')
  lu.assertEquals(type(o.open), 'function')
  lu.assertEquals(type(o.close), 'function')
  lu.assertEquals(type(o.render_separator), 'function')
  lu.assertEquals(type(o.render), 'function')
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
  lu.assertEquals(o._tool_window.is_open, false)
  o:open()
  lu.assertEquals(o._tool_window.is_open, true)
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
  lu.assertEquals(o._tool_window.is_open, true)
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
  lu.assertEquals(o._tool_window.is_open, false)
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
  lu.assertEquals(o._tool_window.is_open, false)
  o:open()
  lu.assertEquals(o._tool_window.is_open, true)
  o:close()
  lu.assertEquals(o._tool_window.is_open, false)
end

app = {
  trap = function(self, f) return xpcall(f, function(e) print(tostring(e)) end) end
}

function TestToolWindow:testRender()
  ImGui = ImGui or {}
  local old_imgui = ImGui

  ImGui = {}

  -- visible, open
  ImGui.Begin = function(_, _, _, _) return true, true end

  ImGui.Cond_Appearing = function() return 1 end
  ImGui.Cond_FirstUseEver = function() return 2 end
  ImGui.End = function() end
  ImGui.GetWindowViewport = function() end
  ImGui.SetNextWindowPos = function(_, _, _, _, _, _) end
  ImGui.SetNextWindowSize = function(_, _, _, _) end
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
  lu.assertEquals(o._tool_window.is_open, false)
  lu.assertEquals(render_content_called, false)

  o:open()
  o:render()
  lu.assertEquals(o._tool_window.is_open, true)
  lu.assertEquals(render_content_called, true)

  render_content_called = false
  o:close()
  o:render()
  lu.assertEquals(o._tool_window.is_open, false)
  lu.assertEquals(render_content_called, false)

  ImGui.Begin = function(_, _, _, _) return false end

  o:render()
  lu.assertEquals(o._tool_window.is_open, false)
  lu.assertEquals(render_content_called, false)

  ImGui = old_imgui
end

function TestToolWindow:testRenderSeparator()
  local test_class = Polo {
    init = function(self)
      ToolWindow.init(self)
    end
  }

  local o = test_class.new()

  lu.assertEquals(type(test_class.new().render_separator), 'function')
end

--

os.exit(lu.LuaUnit.run())