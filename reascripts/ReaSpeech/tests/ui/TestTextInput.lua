package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Ctx')
require('libs/Trap')
require('ui/Widgets')
require('ui/widgets/TextInput')

--

TestTextInput = {}

function TestTextInput:setUp()
  ImGui.IsItemDeactivated = function() return false end
end

local function fake_widget(options, committed)
  options.disabled = options.disabled or function() return false end
  options.on_change = options.on_change or function() end
  options.on_enter = options.on_enter or function() end
  options.on_cancel = options.on_cancel or function() end
  return {
    options = options,
    render_label = function() end,
    value = function() return options.default or '' end,
    set = function(_, value) table.insert(committed, value) end,
  }
end

-- The flags and callback options pass straight through to InputText;
-- each may be a plain value or a function returning one (a callback
-- usually needs lazy creation against a live context)
function TestTextInput:testPassesFlagsAndCallbackThrough()
  local captured
  ImGui.InputText = function(_ctx, _label, buf, flags, callback)
    captured = { flags = flags, callback = callback }
    return false, buf
  end

  local sentinel = {}
  Widgets.TextInput.renderer(fake_widget({ label = 't', flags = 42, callback = sentinel }, {}))

  lu.assertEquals(captured.flags, 42)
  lu.assertIs(captured.callback, sentinel)
end

function TestTextInput:testFunctionValuedFlagsAndCallback()
  local captured
  ImGui.InputText = function(_ctx, _label, buf, flags, callback)
    captured = { flags = flags, callback = callback }
    return false, buf
  end

  local sentinel = {}
  Widgets.TextInput.renderer(fake_widget({
    label = 't',
    flags = function() return 7 end,
    callback = function() return sentinel end,
  }, {}))

  lu.assertEquals(captured.flags, 7)
  lu.assertIs(captured.callback, sentinel)
end

-- A callback with no flags still needs a valid flags argument in the
-- positional slot ahead of it
function TestTextInput:testCallbackWithoutFlagsGetsNoneFlags()
  local none_flags = 0
  ImGui.InputTextFlags_None = function() return none_flags end

  local captured
  ImGui.InputText = function(_ctx, _label, buf, flags, callback)
    captured = { flags = flags, callback = callback }
    return false, buf
  end

  local sentinel = {}
  Widgets.TextInput.renderer(fake_widget({ label = 't', callback = sentinel }, {}))

  lu.assertEquals(captured.flags, none_flags)
  lu.assertIs(captured.callback, sentinel)
end

function TestTextInput:testNoOptionsPassesNilFlags()
  local captured_count
  ImGui.InputText = function(_ctx, _label, buf, flags, callback)
    captured_count = select('#', flags, callback)
    lu.assertNil(flags)
    lu.assertNil(callback)
    return false, buf
  end

  Widgets.TextInput.renderer(fake_widget({ label = 't' }, {}))

  lu.assertEquals(captured_count, 2)
end

-- The hint path takes the same pass-through
function TestTextInput:testHintPathPassesFlagsAndCallback()
  local captured
  ImGui.InputTextWithHint = function(_ctx, _label, _hint, buf, flags, callback)
    captured = { flags = flags, callback = callback }
    return false, buf
  end

  local sentinel = {}
  Widgets.TextInput.renderer(fake_widget({
    label = 't', hint = 'type here', flags = 3, callback = sentinel,
  }, {}))

  lu.assertEquals(captured.flags, 3)
  lu.assertIs(captured.callback, sentinel)
end

--

os.exit(lu.LuaUnit.run())
