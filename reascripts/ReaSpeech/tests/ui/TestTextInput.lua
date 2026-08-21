package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Ctx')
require('libs/Polo')
require('libs/Trap')
require('ui/ReaSpeechWidgets')
require('ui/Widgets')
require('ui/widgets/TextInput')

--

TestTextInput = {}

function TestTextInput:setUp()
  ImGui.IsItemDeactivated = function() return false end
  ImGui.IsKeyPressed = function() return false end
  ImGui.Key_Escape = function() return 27 end
  ImGui.PushID = function() end
  ImGui.PopID = function() end
  ImGui.Text = function() end
  ImGui.Dummy = function() end
  -- the renderer runs inside a Trap, which would otherwise swallow
  -- failed assertions in the ImGui stubs
  self._on_error = Trap.on_error
  Trap.on_error = function(e) error(e, 0) end
end

function TestTextInput:tearDown()
  Trap.on_error = self._on_error
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

-- A real widget whose state is a plain table, so the edit buffer and
-- the committed state can be told apart
local function real_widget(options)
  local state = { value = options.default or '' }
  options.state = {
    get = function() return state.value end,
    set = function(_, value) state.value = value end,
  }
  local widget = Widgets.TextInput.new(options)
  widget.value = function() return state.value end
  widget.set = function(_, value) state.value = value end
  return widget, state
end

local function typing(text)
  ImGui.InputText = function(_ctx, _label, _buf)
    return true, text
  end
end

local function idle()
  ImGui.InputText = function(_ctx, _label, buf)
    return false, buf
  end
end

--

-- Keystrokes accumulate in the edit buffer; state is only written
-- when the edit ends
function TestTextInput:testEditBufferHoldsKeystrokesUntilDeactivation()
  local changes = {}
  local widget, state = real_widget({
    label = 't', default = 'start',
    on_change = function(value) table.insert(changes, value) end,
  })

  typing('s')
  widget:render()
  lu.assertEquals(state.value, 'start')
  lu.assertEquals(widget._edit_buffer, 's')

  typing('st')
  widget:render()
  lu.assertEquals(state.value, 'start')
  lu.assertEquals(widget._edit_buffer, 'st')

  lu.assertEquals(changes, { 's', 'st' })
end

-- The buffer, not state, is what InputText sees mid-edit
function TestTextInput:testRendersEditBufferWhileEditing()
  local widget = real_widget({ label = 't', default = 'start' })
  typing('typed')
  widget:render()

  local seen
  ImGui.InputText = function(_ctx, _label, buf)
    seen = buf
    return false, buf
  end
  widget:render()

  lu.assertEquals(seen, 'typed')
end

function TestTextInput:testDeactivationCommitsBufferAndFiresOnEnter()
  local entered = {}
  local widget, state = real_widget({
    label = 't', default = 'start',
    on_enter = function(value) table.insert(entered, value) end,
  })

  typing('final')
  widget:render()

  idle()
  ImGui.IsItemDeactivated = function() return true end
  widget:render()

  lu.assertEquals(state.value, 'final')
  lu.assertEquals(entered, { 'final' })
  lu.assertNil(widget._edit_buffer)
end

-- Deactivating without having typed reports the current value and
-- leaves state alone
function TestTextInput:testDeactivationWithoutEditFiresOnEnterWithValue()
  local entered = {}
  local sets = 0
  local widget, state = real_widget({
    label = 't', default = 'start',
    on_enter = function(value) table.insert(entered, value) end,
  })
  widget.set = function(_, value) sets = sets + 1; state.value = value end

  idle()
  ImGui.IsItemDeactivated = function() return true end
  widget:render()

  lu.assertEquals(entered, { 'start' })
  lu.assertEquals(sets, 0)
end

function TestTextInput:testEscapeCancelsWithoutCommitting()
  local cancels = 0
  local entered = {}
  local widget, state = real_widget({
    label = 't', default = 'start',
    on_cancel = function() cancels = cancels + 1 end,
    on_enter = function(value) table.insert(entered, value) end,
  })

  typing('abandoned')
  widget:render()

  idle()
  ImGui.IsItemDeactivated = function() return true end
  ImGui.IsKeyPressed = function(_ctx, key) return key == ImGui.Key_Escape() end
  widget:render()

  lu.assertEquals(state.value, 'start')
  lu.assertEquals(cancels, 1)
  lu.assertEquals(entered, {})
  lu.assertNil(widget._edit_buffer)
end

-- clear_edit_buffer abandons the in-progress edit so the next render
-- reads from state again (used when the value changes programmatically
-- mid-edit)
function TestTextInput:testClearEditBufferRereadsState()
  local widget, state = real_widget({ label = 't', default = 'start' })

  typing('partial')
  widget:render()
  lu.assertEquals(widget._edit_buffer, 'partial')

  state.value = 'replaced'
  widget:clear_edit_buffer()

  local seen
  ImGui.InputText = function(_ctx, _label, buf)
    seen = buf
    return false, buf
  end
  widget:render()

  lu.assertEquals(seen, 'replaced')
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
