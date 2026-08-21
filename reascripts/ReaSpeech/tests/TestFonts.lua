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

function TestFonts:testRegisterRequiresArguments()
  lu.assertErrorMsgContains('name, font_family, and size are required', function()
    Fonts:register('mono', nil, 2)
  end)
end

function TestFonts:testRegisteredFontReloadsWithSizeChanges()
  local old_create = ImGui.CreateFont
  local old_attach, old_detach = ImGui.Attach, ImGui.Detach
  local old_validate = ImGui.ValidatePtr
  local old_none, old_bold = ImGui.FontFlags_None, ImGui.FontFlags_Bold

  ImGui.CreateFont = function(name, flags) return { name = name, flags = flags } end
  ImGui.Attach = function() end
  ImGui.Detach = function() end
  ImGui.ValidatePtr = function() return true end
  ImGui.FontFlags_None = function() return 0 end
  ImGui.FontFlags_Bold = function() return 1 end

  Fonts._attached_ctx = {}
  Fonts:register('mono', 'monospace', 4)
  lu.assertTrue(Fonts._has_new_fonts)

  Fonts:load_and_attach('ctx', 10)
  lu.assertEquals(Fonts.mono.size, 14)
  lu.assertEquals(Fonts.mono.object.name, 'monospace')

  -- a size change rebuilds registered fonts at the new relative size
  Fonts:load_and_attach('ctx', 12)
  lu.assertEquals(Fonts.mono.size, 16)

  Fonts.registered_fonts = nil
  Fonts.mono = nil
  Fonts._has_new_fonts = false
  ImGui.CreateFont = old_create
  ImGui.Attach, ImGui.Detach = old_attach, old_detach
  ImGui.ValidatePtr = old_validate
  ImGui.FontFlags_None, ImGui.FontFlags_Bold = old_none, old_bold
end

--

os.exit(lu.LuaUnit.run())
