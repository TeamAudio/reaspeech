package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('ui/Fonts')

--

TestFonts = {}

function TestFonts:testWrap()
  local old_imgui = ImGui or {}

  local push_called = false
  local pop_called = false
  ImGui.PushFont = function(_, _font, _size)
    push_called = true
  end
  ImGui.PopFont = function(_)
    pop_called = true
  end

  local old_reaper = reaper or {}

  local function_called = false
  Fonts.wrap("context", "font", function()
    function_called = true
  end)

  lu.assertTrue(push_called)
  lu.assertTrue(pop_called)
  lu.assertTrue(function_called)
  lu.assertTrue(function_called)

  ImGui = old_imgui
  reaper = old_reaper
end

function TestFonts:testCreateFont()
  local old_create_font = ImGui.CreateFont
  ImGui.CreateFont = function(_, name, size)
    -- object will be an actual font object in the real implementation
    return { object = 'sans-serif', size = size }
  end

  local font = Fonts:create_font('sans-serif', 12)

  lu.assertEquals(font.object, ImGui.CreateFont('sans-serif', 12))

  lu.assertEquals(font.size, 12)

  ImGui.CreateFont = old_create_font
end

function TestFonts:testWrapErrorHandler()
  local old_imgui = ImGui

  local push_called = false
  local pop_called = false
  ImGui.PushFont = function(_, _font, _size)
    push_called = true
  end
  ImGui.PopFont = function()
    pop_called = true
  end

  local function_called = false
  local error_called = false
  Fonts.wrap("context", "font", function()
    function_called = true
    error("test error")
  end, function(f)
    return xpcall(f, function(msg)
      error_called = true
      lu.assertEquals(msg, "test error")
    end)
  end)

  lu.assertTrue(push_called)
  lu.assertTrue(pop_called)
  lu.assertTrue(function_called)
  lu.assertTrue(error_called)

  ImGui = old_imgui
end

function TestFonts:testErrorHandlerDefault()
  local old_imgui = ImGui
  local old_reaper = reaper

  local push_called = false
  ImGui.PushFont = function(_, _font, _size)
    push_called = true
  end

  local pop_called = false
  ImGui.PopFont = function()
    pop_called = true
  end

  local error_called = false
  reaper.ShowConsoleMsg = function(msg)
    error_called = true
    lu.assertEquals(msg, 'test error')
  end

  local function_called = false
  Fonts.wrap("context", "font", function()
    function_called = true
    error("test error")
  end)

  lu.assertTrue(push_called)
  lu.assertTrue(pop_called)
  lu.assertTrue(function_called)
  lu.assertTrue(error_called)

  ImGui = old_imgui
  reaper = old_reaper
end

--

os.exit(lu.LuaUnit.run())
